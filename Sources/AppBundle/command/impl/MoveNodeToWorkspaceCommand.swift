import Common

struct MoveNodeToWorkspaceCommand: Command {
    let args: MoveNodeToWorkspaceCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
        let subjectWs = window.nodeWorkspace
        let targetWorkspace: Workspace
        switch args.target.val {
            case .relative(let nextPrev):
                guard let subjectWs else { return .fail(io.err("Window \(window.windowId) doesn't belong to any workspace")) }
                let ws = getNextPrevWorkspace(
                    current: subjectWs,
                    isNext: nextPrev == .next,
                    wrapAround: args.wrapAround,
                    stdin: args.useStdin ? io.readStdin() : nil,
                    target: target,
                )
                guard let ws = ws.getOrNil(appendErrorTo: &io.stderr) else { return .fail }
                targetWorkspace = ws
            case .direct(let name):
                targetWorkspace = Workspace.get(byName: name.raw)
        }
        return moveWindowToWorkspace(
            window,
            targetWorkspace,
            io,
            parent: args.parent,
            focusFollowsWindow: args.focusFollowsWindow,
            failIfNoop: args.failIfNoop,
        )
    }
}

/// - Parameter parent: Move the parent container of the window instead of the window itself (`--parent` flag)
@MainActor
func moveWindowToWorkspace(
    _ window: Window,
    _ targetWorkspace: Workspace,
    _ io: CmdIo,
    parent: Bool,
    focusFollowsWindow: Bool,
    failIfNoop: Bool,
    index: Int = INDEX_BIND_LAST,
) -> BinaryExitCode {
    let node: TreeNode
    if parent {
        guard let container = window.parentContainerToMoveOrReportError(io) else { return .fail }
        node = container
    } else {
        node = window
    }
    if node.nodeWorkspace == targetWorkspace {
        let nodeDescription = parent ? "The parent container of window '\(window.windowId)'" : "Window '\(window.windowId)'"
        return switch failIfNoop {
            case true: .fail
            case false:
                .succ(io.err("\(nodeDescription) already belongs to workspace '\(targetWorkspace.name)'. Tip: use --fail-if-noop to exit with non-zero code"))
        }
    }
    // With --parent, the window is always a tiling window, so its parent container goes to the root tiling container
    let targetContainer: NonLeafTreeNodeObject = window.isFloating
        ? targetWorkspace.floatingWindowsContainer
        : targetWorkspace.rootTilingContainer
    node.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: index)
    return .from(bool: focusFollowsWindow ? window.focusWindow() : true)
}
