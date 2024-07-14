import Common

struct MoveNodeToWorkspaceCommand: Command {
    let args: MoveNodeToWorkspaceCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let focus = args.resolveFocusOrReportError(env, io) else { return false }
        guard let window = focus.windowOrNil else {
            return io.err(noWindowIsFocused)
        }
        let prevWorkspace = window.workspace ?? focus.workspace
        let targetWorkspace: Workspace
        switch args.target.val {
            case .relative(let isNext):
                guard let workspace = getNextPrevWorkspace(current: prevWorkspace, isNext: isNext, wrapAround: args.wrapAround, stdin: io.readStdin()) else { return false }
                targetWorkspace = workspace
            case .direct(let name):
                targetWorkspace = Workspace.get(byName: name.raw)
        }
        if prevWorkspace == targetWorkspace {
            io.err("Window '\(window.windowId)' already belongs to workspace '\(targetWorkspace.name)'. Tip: use --fail-if-noop to exit with non-zero code")
            return !args.failIfNoop
        }
        let targetContainer: NonLeafTreeNodeObject = window.isFloating ? targetWorkspace : targetWorkspace.rootTilingContainer
        window.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        return prevWorkspace.focusWorkspace()
    }

    public static func run(_ env: CmdEnv, _ io: CmdIo, _ name: String) -> Bool {
        if let wName = WorkspaceName.parse(name).getOrNil(appendErrorTo: &io.stderr) {
            var args = MoveNodeToWorkspaceCmdArgs(rawArgs: [])
            args.target = .initialized(.direct(wName))
            return MoveNodeToWorkspaceCommand(args: args).run(env, io)
        } else {
            return false
        }
    }
}
