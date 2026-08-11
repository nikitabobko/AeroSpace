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
        switch currentWindow.windowParentCases {
            case .unbound: return .fail
            case .tilingContainer(let parent):
                guard let indexOfCurrent = currentWindow.ownIndex else { return .fail(io.err(bugPrompt())) }
                let indexOfSiblingTarget = indexOfCurrent + direction.focusOffset
                if parent.orientation == direction.orientation && parent.children.indices.contains(indexOfSiblingTarget) {
                    switch parent.children[indexOfSiblingTarget].tilingTreeNodeCasesOrDie() {
                        case .tilingContainer(let topLevelSiblingTargetContainer):
                            return deepMoveIn(window: currentWindow, into: topLevelSiblingTargetContainer, moveDirection: direction, io)
                        case .window: // "swap windows"
                            let prevBinding = currentWindow.unbindFromParent()
                            currentWindow.bind(to: parent, adaptiveWeight: prevBinding.adaptiveWeight, index: indexOfSiblingTarget)
                            return .succ
                    }
                } else {
                    return moveOut(tilingWindow: currentWindow, direction: direction, io, args, env)
                }
            case .floatingWindowsContainer: // floating window
                return .fail(io.err("moving floating windows isn't yet supported")) // todo
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
                return .fail(io.err(moveOutMacosUnconventionalWindow))
            case .macosPopupWindowsContainer:
                return .fail(io.err(bugPrompt())) // Impossible
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
                case .createImplicitContainerOrFail:
                    return createImplicitContainerAndMoveWindowOrFail(window, workspace, direction, io)
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
                return hitAllMonitorsOuterFrameBoundaries(window, workspace, args, direction, io)
            }
    }
}

@MainActor private func hitAllMonitorsOuterFrameBoundaries(
    _ window: Window,
    _ workspace: Workspace,
    _ args: MoveCmdArgs,
    _ direction: CardinalDirection,
    _ io: CmdIo,
) -> BinaryExitCode {
    switch args.boundariesAction {
        case .stop: return .succ
        case .fail: return .fail
        case .createImplicitContainer:
            createImplicitContainerAndMoveWindow(window, workspace, direction)
            return .succ
        case .createImplicitContainerOrFail:
            return createImplicitContainerAndMoveWindowOrFail(window, workspace, direction, io)
    }
}

private let moveOutMacosUnconventionalWindow = "moving macOS fullscreen, minimized windows and windows of hidden apps isn't yet supported. This behavior is subject to change"

@MainActor private func moveOut(
    tilingWindow window: Window,
    direction: CardinalDirection,
    _ io: CmdIo,
    _ args: MoveCmdArgs,
    _ env: CmdEnv,
) -> BinaryExitCode {
    let innerMostTilingContainer = window.parents.first(where: {
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
            window.bind(to: parent, adaptiveWeight: WEIGHT_AUTO, index: ownIndex + direction.insertionOffset)
            return .succ
        case .workspace(let parent):
            return hitWorkspaceBoundaries(window, parent, io, args, direction, env)
    }
}

@MainActor private func createImplicitContainerAndMoveWindowOrFail(
    _ window: Window,
    _ workspace: Workspace,
    _ direction: CardinalDirection,
    _ io: CmdIo,
) -> BinaryExitCode {
    if !config.enableNormalizationFlattenContainers {
        io.out("Tip: create-implicit-container-or-fail will never cause the move command to fail since enable-normalization-flatten-containers is disabled")
        createImplicitContainerAndMoveWindow(window, workspace, direction)
        return .succ
    }
    let prevRoot = workspace.rootTilingContainer
    let prevOrientation = prevRoot.orientation
    let prevChildren = prevRoot.children
    createImplicitContainerAndMoveWindow(window, workspace, direction)
    workspace.normalizeContainers()
    let newRoot = workspace.rootTilingContainer
    if newRoot.orientation == prevOrientation && newRoot.children.count == prevChildren.count && zip(newRoot.children, prevChildren).allSatisfy({ $0 === $1 }) {
        return .fail
    }
    return .succ
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

@MainActor private func deepMoveIn(window: Window, into container: TilingContainer, moveDirection: CardinalDirection, _ io: CmdIo) -> BinaryExitCode {
    let deepTarget = container.tilingTreeNodeCasesOrDie().findDeepMoveInTargetRecursive(moveDirection.orientation)
    switch deepTarget {
        case .tilingContainer(let deepTarget):
            window.bind(to: deepTarget, adaptiveWeight: WEIGHT_AUTO, index: 0)
        case .window(let deepTarget):
            guard let parent = deepTarget.parent as? TilingContainer else { return .fail(io.err(bugPrompt())) }
            guard let deepTargetIndex = deepTarget.ownIndex else { return .fail(io.err(bugPrompt())) }
            window.bind(to: parent, adaptiveWeight: WEIGHT_AUTO, index: deepTargetIndex + 1)
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
