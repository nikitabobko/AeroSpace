import Common

struct MoveNodeToWorkspaceCommand: Command {
    let args: MoveNodeToWorkspaceCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        guard let focused = state.subject.windowOrNil else {
            state.stdout.append(noWindowIsFocused)
            return false
        }
        let preserveWorkspace = focused.workspace
        let targetWorkspace: Workspace
        switch args.target {
        case .relative(let relative):
            guard let workspace = getNextPrevWorkspace(current: state.subject.workspace, relative: relative, stdin: stdin) else { return false }
            targetWorkspace = workspace
        case .direct(let direct):
            targetWorkspace = Workspace.get(byName: direct.name.raw)
        }
        if preserveWorkspace == targetWorkspace {
            return true
        }
        let targetContainer: NonLeafTreeNode = focused.isFloating ? targetWorkspace : targetWorkspace.rootTilingContainer
        focused.unbindFromParent()
        focused.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        return WorkspaceCommand.run(state, preserveWorkspace.name)
    }
}
