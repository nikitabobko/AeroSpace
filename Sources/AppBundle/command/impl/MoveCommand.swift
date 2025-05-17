import AppKit
import Common

struct MoveCommand: Command {
    let args: MoveCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let direction = args.direction.val
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let currentWindow = target.windowOrNil else {
            return io.err(noWindowIsFocused)
        }
        guard let parent = currentWindow.parent else { return false }
        switch parent.cases {
            case .tilingContainer(let parent):
                let indexOfCurrent = currentWindow.ownIndex
                let indexOfSiblingTarget = indexOfCurrent + direction.focusOffset
                if parent.orientation == direction.orientation && parent.children.indices.contains(indexOfSiblingTarget) {
                    switch parent.children[indexOfSiblingTarget].tilingTreeNodeCasesOrDie() {
                        case .tilingContainer(let topLevelSiblingTargetContainer):
                            return deepMoveIn(window: currentWindow, into: topLevelSiblingTargetContainer, moveDirection: direction)
                        case .window: // "swap windows"
                            let prevBinding = currentWindow.unbindFromParent()
                            currentWindow.bind(to: parent, adaptiveWeight: prevBinding.adaptiveWeight, index: indexOfSiblingTarget)
                            return true
                    }
                }

                if hasWorkspaceBoundaryInDirection(window: currentWindow, direction: direction) {
                    if args.boundaries == .allMonitorsUnionFrame,
                       let moveNodeToMonitorArgs = parseMoveNodeToMonitorCmdArgs([
                           "--fail-if-noop",
                           "--focus-follows-window",
                           "--window-id", "\(currentWindow.windowId)",
                           direction.rawValue,
                       ]).unwrap().0,
                       MoveNodeToMonitorCommand(args: moveNodeToMonitorArgs).run(env, io)
                    {
                        return true
                    }

                    if args.boundariesAction == .stop {
                        return true
                    }

                    if args.boundariesAction == .fail {
                        return false
                    }
                }

                return moveOut(io, window: currentWindow, direction: direction)
            case .workspace: // floating window
                return io.err("moving floating windows isn't yet supported") // todo
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
                return io.err(moveOutMacosUnconventionalWindow)
            case .macosPopupWindowsContainer:
                return false // Impossible
        }
    }
}

@MainActor private func hasWorkspaceBoundaryInDirection(
    window: Window, direction: CardinalDirection
) -> Bool {
    guard let rootTilingContainer = window.nodeWorkspace?.rootTilingContainer else {
        return false // Shouldn't happen
    }

    guard let windowParent = window.parent else {
        return false // Shouldn't happen
    }

    if windowParent != rootTilingContainer {
        return false
    }

    if rootTilingContainer.orientation != direction.orientation {
        return false
    }

    switch direction {
        case .left, .up:
            return window.ownIndex == 0
        case .right, .down:
            return window.ownIndex == rootTilingContainer.children.count - 1
    }
}

private let moveOutMacosUnconventionalWindow = "moving macOS fullscreen, minimized windows and windows of hidden apps isn't yet supported. This behavior is subject to change"

@MainActor private func moveOut(_ io: CmdIo, window: Window, direction: CardinalDirection) -> Bool {
    let innerMostChild = window.parents.first(where: {
        return switch $0.parent?.cases {
            case .tilingContainer(let parent): parent.orientation == direction.orientation
            // Stop searching
            case .workspace, .macosMinimizedWindowsContainer, nil, .macosFullscreenWindowsContainer,
                 .macosHiddenAppsWindowsContainer, .macosPopupWindowsContainer: true
        }
    }) as? TilingContainer
    guard let innerMostChild else { return false }
    let bindTo: TilingContainer
    let bindToIndex: Int
    guard let parent = innerMostChild.parent else { return false }
    switch parent.nodeCases {
        case .tilingContainer(let parent):
            check(parent.orientation == direction.orientation)
            bindTo = parent
            guard let ownIndex = innerMostChild.ownIndex else { return false }
            bindToIndex = ownIndex + direction.insertionOffset
        case .workspace(let parent): // create implicit container
            let prevRoot = parent.rootTilingContainer
            prevRoot.unbindFromParent()
            // Force tiles layout
            _ = TilingContainer(parent: parent, adaptiveWeight: WEIGHT_AUTO, direction.orientation, .tiles, index: 0)
            check(prevRoot != parent.rootTilingContainer)
            prevRoot.bind(to: parent.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: 0)

            bindTo = parent.rootTilingContainer
            bindToIndex = direction.insertionOffset
        case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
            return io.err(moveOutMacosUnconventionalWindow)
        case .macosPopupWindowsContainer:
            return false // Impossible
        case .window:
            die("Window can't contain children nodes")
    }

    window.bind(
        to: bindTo,
        adaptiveWeight: WEIGHT_AUTO,
        index: bindToIndex
    )
    return true
}

@MainActor private func deepMoveIn(window: Window, into container: TilingContainer, moveDirection: CardinalDirection) -> Bool {
    let deepTarget = container.tilingTreeNodeCasesOrDie().findDeepMoveInTargetRecursive(moveDirection.orientation)
    switch deepTarget {
        case .tilingContainer(let deepTarget):
            window.bind(to: deepTarget, adaptiveWeight: WEIGHT_AUTO, index: 0)
        case .window(let deepTarget):
            guard let parent = deepTarget.parent as? TilingContainer else { return false }
            window.bind(
                to: parent,
                adaptiveWeight: WEIGHT_AUTO,
                index: deepTarget.ownIndex + 1
            )
    }
    return true
}

private extension TilingTreeNodeCases {
    @MainActor func findDeepMoveInTargetRecursive(_ orientation: Orientation) -> TilingTreeNodeCases {
        return switch self {
            case .window:
                self
            case .tilingContainer(let container):
                if container.orientation == orientation {
                    .tilingContainer(container)
                } else {
                    (container.mostRecentChild ?? dieT("Empty containers must be detached during normalization"))
                        .tilingTreeNodeCasesOrDie()
                        .findDeepMoveInTargetRecursive(orientation)
                }
        }
    }
}
