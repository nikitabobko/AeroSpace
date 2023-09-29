struct MoveContainerToWorkspaceCommand: Command {
    let targetWorkspaceName: String

    func runWithoutRefresh() async {
        guard let focused = focusedWindow else { return }
        let preserveWorkspace = focused.workspace
        let targetWorkspace = Workspace.get(byName: targetWorkspaceName)
        let targetContainer = focused.isFloating ? targetWorkspace : targetWorkspace.rootTilingContainer
        focused.unbindFromParent()
        let weight: CGFloat
        if let targetContainer = targetContainer as? TilingContainer {
            weight = targetContainer.children.sumOf { $0.getWeight(targetContainer.orientation) }
                .div(targetContainer.children.count) ?? 1
        } else {
            weight = 1
        }
        focused.bindTo(parent: targetContainer, adaptiveWeight: weight) // todo different monitor

        WorkspaceCommand(workspaceName: preserveWorkspace.name).runWithoutRefresh()
    }
}
