import Common

struct MoveNodeToWorkspaceCommand: Command {
    let args: MoveNodeToWorkspaceCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        guard let focused = state.subject.windowOrNil else {
            state.stderr.append(noWindowIsFocused)
            return false
        }
        let prevWorkspace = focused.workspace ?? Workspace.focused
        let targetWorkspace: Workspace
        switch args.target {
        case .relative(let relative):
            guard let workspace = getNextPrevWorkspace(current: prevWorkspace, relative: relative, stdin: stdin) else { return false }
            targetWorkspace = workspace
        case .direct(let direct):
            targetWorkspace = Workspace.get(byName: direct.name.raw)
        }
        if prevWorkspace == targetWorkspace {
            return true
        }
        let targetContainer: NonLeafTreeNodeObject = focused.isFloating ? targetWorkspace : targetWorkspace.rootTilingContainer
        focused.unbindFromParent()
        focused.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        return WorkspaceCommand.run(state, prevWorkspace.name)
    }
}
