import AppKit
import Common

struct MoveCommand: Command {
    let args: MoveCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        let direction = args.direction.val
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let currentWindow = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        guard let parent = currentWindow.parent else { return .fail }
        switch parent.cases {
            case .tilingContainer(let parent):
                let indexOfCurrent = currentWindow.ownIndex.orDie()
                let indexOfSiblingTarget = indexOfCurrent + direction.focusOffset
                if parent.orientation == direction.orientation && parent.children.indices.contains(indexOfSiblingTarget) {
                    switch parent.children[indexOfSiblingTarget].tilingTreeNodeCasesOrDie() {
                        case .tilingContainer(let topLevelSiblingTargetContainer):
                            return deepMoveIn(window: currentWindow, into: topLevelSiblingTargetContainer, moveDirection: direction)
                        case .window: // "swap windows"
                            let prevBinding = currentWindow.unbindFromParent()
                            currentWindow.bind(to: parent, adaptiveWeight: prevBinding.adaptiveWeight, index: indexOfSiblingTarget)
                            return .succ
                    }
                } else {
                    // Only hijack the edge `move` for a size toggle when there is actually a
                    // same-orientation split to resize. Otherwise fall through to the normal
                    // moveOut (e.g. move-up in an all-horizontal layout must still move/reorganize).
                    if config.moveResizeToggleAtEdge, isAtExtremeEdge(currentWindow, direction),
                       let exit = resizeToggleAtEdge(window: currentWindow, direction: direction)
                    {
                        return exit
                    }
                    return moveOut(window: currentWindow, direction: direction, io, args, env)
                }
            case .workspace: // floating window
                return .fail(io.err("moving floating windows isn't yet supported")) // todo
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
                return .fail(io.err(moveOutMacosUnconventionalWindow))
            case .macosPopupWindowsContainer:
                return .fail // Impossible
        }
    }
}

@MainActor private func hitWorkspaceBoundaries(
    _ window: Window,
    _ workspace: Workspace,
    _ io: CmdIo,
    _ args: MoveCmdArgs,
    _ direction: CardinalDirection,
    _ env: CmdEnv,
) -> BinaryExitCode {
    switch args.boundaries {
        case .workspace:
            switch args.boundariesAction {
                case .stop: return .succ
                case .fail: return .fail
                case .createImplicitContainer:
                    createImplicitContainerAndMoveWindow(window, workspace, direction)
                    return .succ
            }
        case .allMonitorsOuterFrame:
            guard let (monitors, index) = window.nodeMonitor?.findRelativeMonitor(inDirection: direction) else {
                return .fail(io.err("Should never happen. Can't find the current monitor"))
            }

            if monitors.indices.contains(index) {
                let moveNodeToMonitorArgs = MoveNodeToMonitorCmdArgs(target: .direction(direction))
                    .copy(\.windowId, window.windowId)
                    .copy(\.focusFollowsWindow, focus.windowOrNil == window)

                return MoveNodeToMonitorCommand(args: moveNodeToMonitorArgs).run(env, io)
            } else {
                return hitAllMonitorsOuterFrameBoundaries(window, workspace, args, direction)
            }
    }
}

@MainActor private func hitAllMonitorsOuterFrameBoundaries(
    _ window: Window,
    _ workspace: Workspace,
    _ args: MoveCmdArgs,
    _ direction: CardinalDirection,
) -> BinaryExitCode {
    switch args.boundariesAction {
        case .stop: return .succ
        case .fail: return .fail
        case .createImplicitContainer:
            createImplicitContainerAndMoveWindow(window, workspace, direction)
            return .succ
    }
}

private let moveOutMacosUnconventionalWindow = "moving macOS fullscreen, minimized windows and windows of hidden apps isn't yet supported. This behavior is subject to change"

@MainActor private func moveOut(
    window: Window,
    direction: CardinalDirection,
    _ io: CmdIo,
    _ args: MoveCmdArgs,
    _ env: CmdEnv,
) -> BinaryExitCode {
    let innerMostChild = window.parents.first(where: {
        return switch $0.parent?.cases {
            case .tilingContainer(let parent): parent.orientation == direction.orientation
            // Stop searching
            case .workspace, .macosMinimizedWindowsContainer, nil, .macosFullscreenWindowsContainer,
                 .macosHiddenAppsWindowsContainer, .macosPopupWindowsContainer: true
        }
    }) as? TilingContainer
    guard let innerMostChild else { return .fail }
    guard let parent = innerMostChild.parent else { return .fail }
    switch parent.cases {
        case .tilingContainer(let parent):
            check(parent.orientation == direction.orientation)
            guard let ownIndex = innerMostChild.ownIndex else { return .fail }
            window.bind(to: parent, adaptiveWeight: WEIGHT_AUTO, index: ownIndex + direction.insertionOffset)
            return .succ
        case .workspace(let parent):
            return hitWorkspaceBoundaries(window, parent, io, args, direction, env)
        case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
            return .fail(io.err(moveOutMacosUnconventionalWindow))
        case .macosPopupWindowsContainer:
            return .fail // Impossible
    }
}

@MainActor private func createImplicitContainerAndMoveWindow(
    _ window: Window,
    _ workspace: Workspace,
    _ direction: CardinalDirection,
) {
    let prevRoot = workspace.rootTilingContainer
    prevRoot.unbindFromParent()
    // Force tiles layout
    _ = TilingContainer(parent: workspace, adaptiveWeight: WEIGHT_AUTO, direction.orientation, .tiles, index: 0)
    check(prevRoot != workspace.rootTilingContainer)
    prevRoot.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: 0)
    window.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: direction.insertionOffset)
}

@MainActor private func deepMoveIn(window: Window, into container: TilingContainer, moveDirection: CardinalDirection) -> BinaryExitCode {
    let deepTarget = container.tilingTreeNodeCasesOrDie().findDeepMoveInTargetRecursive(moveDirection.orientation)
    switch deepTarget {
        case .tilingContainer(let deepTarget):
            window.bind(to: deepTarget, adaptiveWeight: WEIGHT_AUTO, index: 0)
        case .window(let deepTarget):
            guard let parent = deepTarget.parent as? TilingContainer else { return .fail }
            window.bind(
                to: parent,
                adaptiveWeight: WEIGHT_AUTO,
                index: deepTarget.ownIndex.orDie() + 1,
            )
    }
    return .succ
}

/// Fractions of the parent the window cycles through, derived from the configurable
/// `move-resize-toggle-ratios` (percentages). Defaults to 50/60/70 (1/2 -> 3/5 -> 7/10), which keep
/// the neighbour usable on smaller/native screens. Always sorted ascending and clamped to (0, 1).
@MainActor private var resizeToggleRatios: [CGFloat] {
    let ratios = config.moveResizeToggleRatios
        .map { CGFloat($0) / 100 }
        .filter { $0 > 0 && $0 < 1 }
        .sorted()
    return ratios.isEmpty ? [0.5] : ratios
}

/// True when `window` cannot be moved/swapped any further in `direction`: there is no ancestor
/// tiling container (oriented along `direction`) holding a sibling beyond the window in that
/// direction. This is exactly the case where a plain `move` would be a no-op against the edge.
@MainActor private func isAtExtremeEdge(_ window: Window, _ direction: CardinalDirection) -> Bool {
    for node in window.parentsWithSelf {
        guard let parent = node.parent as? TilingContainer else { break }
        if parent.orientation == direction.orientation {
            let siblingIndex = node.ownIndex.orDie() + direction.focusOffset
            if parent.children.indices.contains(siblingIndex) {
                return false // there's a neighbour to move/swap into
            }
        }
    }
    return true
}

/// Cycle the window's size along `direction`'s axis through `resizeToggleRatios` by adjusting the
/// adaptiveWeight of the window's slice within the relevant tiling container. Other siblings keep
/// their weights, so the window simply claims a larger/smaller fraction of the shared axis.
///
/// Returns nil when there is no meaningful same-orientation split to resize, so the caller can fall
/// back to the normal `moveOut` behavior. This guarantees the feature only ADDS a size toggle at
/// real edges and never swallows a move that would otherwise do something.
@MainActor private func resizeToggleAtEdge(window: Window, direction: CardinalDirection) -> BinaryExitCode? {
    let orientation = direction.orientation
    // The node to resize is the window's ancestor (or itself) whose parent is a tiles container
    // oriented along the move axis — the same selection ResizeCommand uses for an explicit axis.
    let node = window.parentsWithSelf.first { node in
        guard let parent = node.parent as? TilingContainer else { return false }
        return parent.layout == .tiles && parent.orientation == orientation
    }
    guard let node, let parent = node.parent as? TilingContainer else { return nil }
    guard parent.children.count > 1 else { return nil } // nothing to share the axis with

    let totalWeight = CGFloat(parent.children.sumOfDouble { $0.getWeight(orientation) })
    let nodeWeight = node.getWeight(orientation)
    let otherWeight = totalWeight - nodeWeight
    guard otherWeight > 0 else { return nil }

    let currentRatio = nodeWeight / totalWeight
    // Pick the next ratio strictly larger than the current one, wrapping back to the first.
    // A small epsilon avoids getting stuck when the current ratio equals a cycle value.
    let ratios = resizeToggleRatios
    let epsilon: CGFloat = 0.01
    let nextRatio = ratios.first { $0 > currentRatio + epsilon } ?? ratios[0]

    // weight that makes node occupy `nextRatio` of the parent, with the other siblings unchanged:
    // nextRatio = newWeight / (newWeight + otherWeight)  =>  newWeight = nextRatio/(1-nextRatio) * otherWeight
    let newWeight = nextRatio / (1 - nextRatio) * otherWeight
    node.setWeight(orientation, newWeight)
    return .succ
}

extension TilingTreeNodeCases {
    @MainActor fileprivate func findDeepMoveInTargetRecursive(_ orientation: Orientation) -> TilingTreeNodeCases {
        switch self {
            case .window:
                self
            case .tilingContainer(let container) where container.orientation == orientation:
                .tilingContainer(container)
            case .tilingContainer(let container):
                container.mostRecentChild.orDie("Empty containers must be detached during normalization")
                    .tilingTreeNodeCasesOrDie()
                    .findDeepMoveInTargetRecursive(orientation)
        }
    }
}
