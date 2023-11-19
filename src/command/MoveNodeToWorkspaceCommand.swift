struct MoveNodeToWorkspaceCommand: Command {
    let targetWorkspaceName: String

    func runWithoutLayout(state: inout FocusState) {
        guard let focused = state.window else { return }
        let preserveWorkspace = focused.workspace
        let targetWorkspace = Workspace.get(byName: targetWorkspaceName)
        if preserveWorkspace == targetWorkspace {
            return
        }
        let targetContainer: NonLeafTreeNode = focused.isFloating ? targetWorkspace : targetWorkspace.rootTilingContainer
        focused.unbindFromParent()
        // todo different monitor for floating windows
        focused.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)

        WorkspaceCommand(workspaceName: preserveWorkspace.name).runWithoutLayout(state: &state)
    }
}
