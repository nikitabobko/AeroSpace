import AppKit
import Common

struct MoveCommand: Command {
    let args: MoveCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        let direction = args.direction.val
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let currentWindow = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        if await shouldFailBecauseFullscreen_nonCancellable(
            window: currentWindow,
            failIfFullscreen: args.failIfFullscreen,
            failIfMacosNativeFullscreen: args.failIfMacosNativeFullscreen,
        ) {
            return .fail
        }
        let node: TreeNode // The node to move. Either the window itself or its parent container
        let parent: TilingContainer
        if args.parent {
            guard let container = currentWindow.parentContainerToMoveOrReportError(io) else { return .fail }
            guard let containerParent = container.parent as? TilingContainer else { return .fail(io.err(bugPrompt())) }
            node = container
            parent = containerParent
        } else {
            switch currentWindow.windowParentCases {
                case .unbound: return .fail
                case .tilingContainer(let windowParent):
                    node = currentWindow
                    parent = windowParent
                case .floatingWindowsContainer: // floating window
                    return .fail(io.err("moving floating windows isn't yet supported")) // todo
                case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
                    return .fail(io.err(moveOutMacosUnconventionalWindow))
                case .macosPopupWindowsContainer:
                    return .fail(io.err(bugPrompt())) // Impossible
            }
        }
        guard let indexOfCurrent = node.ownIndex else { return .fail(io.err(bugPrompt())) }
        let indexOfSiblingTarget = indexOfCurrent + direction.focusOffset
        if parent.orientation == direction.orientation && parent.children.indices.contains(indexOfSiblingTarget) {
            switch parent.children[indexOfSiblingTarget].tilingTreeNodeCasesOrDie() {
                case .tilingContainer(let topLevelSiblingTargetContainer):
                    return deepMoveIn(node: node, into: topLevelSiblingTargetContainer, moveDirection: direction, io)
                case .window: // "swap windows"
                    let prevBinding = node.unbindFromParent()
                    node.bind(to: parent, adaptiveWeight: prevBinding.adaptiveWeight, index: indexOfSiblingTarget)
                    return .succ
            }
        } else {
            return moveOut(tilingNode: node, window: currentWindow, direction: direction, io, args, env)
        }
    }
}

extension Window {
    /// The node that `--parent` flag of `move`, `move-node-to-workspace` and `move-node-to-monitor` commands operates on
    @MainActor
    func parentContainerToMoveOrReportError(_ io: CmdIo) -> TilingContainer? {
        switch windowParentCases {
            case .unbound:
                return nil
            case .tilingContainer(let parent):
                switch parent.tilingContainerParentCases {
                    case .unbound:
                        return nil
                    case .tilingContainer:
                        return parent
                    case .workspace:
                        io.err("Can't move the parent container of window \(windowId): it's the root container of the workspace")
                        return nil
                }
            case .floatingWindowsContainer,
                 .macosMinimizedWindowsContainer,
                 .macosFullscreenWindowsContainer,
                 .macosHiddenAppsWindowsContainer,
                 .macosPopupWindowsContainer:
                io.err("Can't move the parent container of window \(windowId): the window isn't a tiling window")
                return nil
        }
    }
}

/// - Parameters:
///   - node: The node to move. Either `window` itself or its parent container (`--parent` flag)
@MainActor private func hitWorkspaceBoundaries(
    _ node: TreeNode,
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
                    createImplicitContainerAndMoveNode(node, workspace, direction)
                    return .succ
            }
        case .allMonitorsOuterFrame:
            guard let (monitors, index) = window.nodeMonitor?.findRelativeMonitor(inDirection: direction) else {
                return .fail(io.err("Should never happen. Can't find the current monitor"))
            }

            if monitors.indices.contains(index) {
                let moveNodeToMonitorArgs = MoveNodeToMonitorCmdArgs(target: .direction(direction))
                    .copy(\.windowId, window.windowId)
                    .copy(\.parent, args.parent)
                    .copy(\.focusFollowsWindow, focus.windowOrNil == window)

                return MoveNodeToMonitorCommand(args: moveNodeToMonitorArgs).run(env, io)
            } else {
                return hitAllMonitorsOuterFrameBoundaries(node, workspace, args, direction)
            }
    }
}

@MainActor private func hitAllMonitorsOuterFrameBoundaries(
    _ node: TreeNode,
    _ workspace: Workspace,
    _ args: MoveCmdArgs,
    _ direction: CardinalDirection,
) -> BinaryExitCode {
    switch args.boundariesAction {
        case .stop: return .succ
        case .fail: return .fail
        case .createImplicitContainer:
            createImplicitContainerAndMoveNode(node, workspace, direction)
            return .succ
    }
}

private let moveOutMacosUnconventionalWindow = "moving macOS fullscreen, minimized windows and windows of hidden apps isn't yet supported. This behavior is subject to change"

@MainActor private func moveOut(
    tilingNode node: TreeNode,
    window: Window,
    direction: CardinalDirection,
    _ io: CmdIo,
    _ args: MoveCmdArgs,
    _ env: CmdEnv,
) -> BinaryExitCode {
    let innerMostTilingContainer = node.parents.first(where: {
        return switch $0.parent?.cases {
            case .tilingContainer(let parent): parent.orientation == direction.orientation
            // Stop searching: we have hit the workspace
            case nil, .workspace: true
            // Impossible: tilingContainer's parent can only be a workspace or tilingContainer
            case .floatingWindowsContainer,
                 .macosMinimizedWindowsContainer,
                 .macosFullscreenWindowsContainer,
                 .macosHiddenAppsWindowsContainer,
                 .macosPopupWindowsContainer: true
        }
    }) as? TilingContainer
    guard let innerMostTilingContainer else { return .fail(io.err(bugPrompt())) } // Impossible
    switch innerMostTilingContainer.tilingContainerParentCases {
        case .unbound: return .fail
        case .tilingContainer(let parent):
            check(parent.orientation == direction.orientation)
            guard let ownIndex = innerMostTilingContainer.ownIndex else { return .fail(io.err(bugPrompt())) }
            node.bind(to: parent, adaptiveWeight: WEIGHT_AUTO, index: ownIndex + direction.insertionOffset)
            return .succ
        case .workspace(let parent):
            return hitWorkspaceBoundaries(node, window, parent, io, args, direction, env)
    }
}

@MainActor private func createImplicitContainerAndMoveNode(
    _ node: TreeNode,
    _ workspace: Workspace,
    _ direction: CardinalDirection,
) {
    let prevRoot = workspace.rootTilingContainer
    prevRoot.unbindFromParent()
    // Force tiles layout
    _ = TilingContainer(parent: workspace, adaptiveWeight: WEIGHT_AUTO, direction.orientation, .tiles, index: 0)
    check(prevRoot != workspace.rootTilingContainer)
    prevRoot.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: 0)
    node.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: direction.insertionOffset)
}

@MainActor private func deepMoveIn(node: TreeNode, into container: TilingContainer, moveDirection: CardinalDirection, _ io: CmdIo) -> BinaryExitCode {
    let deepTarget = container.tilingTreeNodeCasesOrDie().findDeepMoveInTargetRecursive(moveDirection.orientation)
    switch deepTarget {
        case .tilingContainer(let deepTarget):
            node.bind(to: deepTarget, adaptiveWeight: WEIGHT_AUTO, index: 0)
        case .window(let deepTarget):
            guard let parent = deepTarget.parent as? TilingContainer else { return .fail(io.err(bugPrompt())) }
            guard let deepTargetIndex = deepTarget.ownIndex else { return .fail(io.err(bugPrompt())) }
            node.bind(to: parent, adaptiveWeight: WEIGHT_AUTO, index: deepTargetIndex + 1)
    }
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

func shouldFailBecauseFullscreen_nonCancellable(
    window: Window,
    failIfFullscreen: Bool,
    failIfMacosNativeFullscreen: Bool,
) async -> Bool {
    if failIfFullscreen && window.isFullscreen {
        return true
    }
    if failIfMacosNativeFullscreen {
        if true == (try? await window.isMacosFullscreen(.nonCancellable)) {
            return true
        }
    }
    return false
}
