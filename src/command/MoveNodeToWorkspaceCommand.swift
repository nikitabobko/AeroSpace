struct MoveNodeToWorkspaceCommand: Command {
    let args: MoveNodeToWorkspaceCmdArgs

    func _run(_ subject: inout CommandSubject, _ index: Int, _ commands: [any Command]) {
        guard let focused = subject.windowOrNil else { return }
        let preserveWorkspace = focused.workspace
        let targetWorkspace: Workspace
        switch args.target {
        case .workspaceName(let name):
            targetWorkspace = Workspace.get(byName: name)
        }
        if preserveWorkspace == targetWorkspace {
            return
        }
        let targetContainer: NonLeafTreeNode = focused.isFloating ? targetWorkspace : targetWorkspace.rootTilingContainer
        focused.unbindFromParent()
        // todo different monitor for floating windows
        focused.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }
}
