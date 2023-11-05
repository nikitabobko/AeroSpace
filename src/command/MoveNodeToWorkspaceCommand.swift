struct MoveNodeToWorkspaceCommand: Command {
    let targetWorkspaceName: String

    func runWithoutLayout() async {
        guard let focused = focusedWindowOrEffectivelyFocused else { return }
        let preserveWorkspace = focused.workspace
        let targetWorkspace = Workspace.get(byName: targetWorkspaceName)
        if preserveWorkspace == targetWorkspace {
            return
        }
        let targetContainer: NonLeafTreeNode = focused.isFloating ? targetWorkspace : targetWorkspace.rootTilingContainer
        focused.unbindFromParent()
        focused.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST) // todo different monitor

        WorkspaceCommand(workspaceName: preserveWorkspace.name).runWithoutLayout()
    }
}
