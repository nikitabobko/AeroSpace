struct MoveNodeToWorkspaceCommand: Command {
    let targetWorkspaceName: String

    func runWithoutLayout() async {
        guard let focused = focusedWindowOrEffectivelyFocused else { return }
        let preserveWorkspace = focused.workspace
        let targetWorkspace = Workspace.get(byName: targetWorkspaceName)
        let targetContainer: NonLeafTreeNode = focused.isFloating ? targetWorkspace : targetWorkspace.rootTilingContainer
        focused.unbindFromParent()
        focused.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO) // todo different monitor

        WorkspaceCommand(workspaceName: preserveWorkspace.name).runWithoutLayout()
    }
}
