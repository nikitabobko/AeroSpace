import Common

struct MoveNodeToWorkspaceCommand: Command {
    let args: MoveNodeToWorkspaceCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        guard let focused = state.subject.windowOrNil else {
            return state.failCmd(msg: noWindowIsFocused)
        }
        let prevWorkspace = focused.workspace ?? focus.workspace
        let targetWorkspace: Workspace
        switch args.target.val {
            case .relative(let isNext):
                guard let workspace = getNextPrevWorkspace(current: prevWorkspace, isNext: isNext, wrapAround: args.wrapAround, stdin: stdin) else { return false }
                targetWorkspace = workspace
            case .direct(let name):
                targetWorkspace = Workspace.get(byName: name.raw)
        }
        if prevWorkspace == targetWorkspace {
            return state.failCmd(msg: "Window '\(focused.title)' already belongs to workspace '\(targetWorkspace.name)'")
        }
        let targetContainer: NonLeafTreeNodeObject = focused.isFloating ? targetWorkspace : targetWorkspace.rootTilingContainer
        focused.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        let result = prevWorkspace.focusWorkspace()
        state.subject = .focused
        return result
    }

    public static func run(_ state: CommandMutableState, _ name: String) -> Bool {
        if let wName = WorkspaceName.parse(name).getOrNil(appendErrorTo: &state.stderr) {
            var args = MoveNodeToWorkspaceCmdArgs(rawArgs: [])
            args.target = .initialized(.direct(wName))
            return MoveNodeToWorkspaceCommand(args: args).run(state)
        } else {
            return false
        }
    }
}
