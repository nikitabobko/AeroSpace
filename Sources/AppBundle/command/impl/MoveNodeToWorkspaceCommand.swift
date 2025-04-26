import Common

struct MoveNodeToWorkspaceCommand: Command {
    let args: MoveNodeToWorkspaceCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let window = target.windowOrNil else { return io.err(noWindowIsFocused) }
        let subjectWs = window.nodeWorkspace
        let targetWorkspace: Workspace
        switch args.target.val {
            case .relative(let isNext):
                guard let subjectWs else { return io.err("Window \(window.windowId) doesn't belong to any workspace") }
                let ws = getNextPrevWorkspace(
                    current: subjectWs,
                    isNext: isNext,
                    wrapAround: args.wrapAround,
                    stdin: io.readStdin(),
                    target: target
                )
                guard let ws else { return io.err("Can't resolve next or prev workspace") }
                targetWorkspace = ws
            case .direct(let name):
                targetWorkspace = Workspace.get(byName: name.raw)
        }
        if subjectWs == targetWorkspace {
            io.err("Window '\(window.windowId)' already belongs to workspace '\(targetWorkspace.name)'. Tip: use --fail-if-noop to exit with non-zero code")
            return !args.failIfNoop
        }
        let targetContainer: NonLeafTreeNodeObject = window.isFloating ? targetWorkspace : targetWorkspace.rootTilingContainer

        window.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        return args.focusFollowsWindow ? window.focusWindow() : true
    }
}
