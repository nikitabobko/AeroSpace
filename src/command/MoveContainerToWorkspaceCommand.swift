struct MoveContainerToWorkspaceCommand: Command {
    let targetWorkspaceName: String

    func runWithoutRefresh() async {
        guard let focused = focusedWindow else { return }
        let preserveWorkspace = focused.workspace
        let targetWorkspace = Workspace.get(byName: targetWorkspaceName)
        let targetContainer = targetWorkspace.rootTilingContainer
        focused.unbindFromParent()
        let weight = targetContainer.children.sumOf { $0.getWeight(targetContainer.orientation) }
            .div(targetContainer.children.count) ?? 1
        focused.bindTo(parent: targetContainer, adaptiveWeight: weight)

        WorkspaceCommand(workspaceName: preserveWorkspace.name).runWithoutRefresh()
    }
}
