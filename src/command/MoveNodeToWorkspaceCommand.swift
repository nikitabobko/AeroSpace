struct MoveNodeToWorkspaceCommand: Command {
    let args: MoveNodeToWorkspaceCmdArgs

    func _run(_ subject: inout CommandSubject, _ stdout: inout String) -> Bool {
        guard let focused = subject.windowOrNil else {
            stdout += noWindowIsFocused
            return false
        }
        let preserveWorkspace = focused.workspace
        let targetWorkspace: Workspace
        switch args.target {
        case .next:
            fallthrough
        case .prev:
            guard let workspace = getNextPrevWorkspace(current: subject.workspace, target: args.target) else { return false }
            targetWorkspace = workspace
        case .workspaceName(let name, let autoBackAndForth):
            check(!autoBackAndForth)
            targetWorkspace = Workspace.get(byName: name)
        }
        if preserveWorkspace == targetWorkspace {
            return true
        }
        let targetContainer: NonLeafTreeNode = focused.isFloating ? targetWorkspace : targetWorkspace.rootTilingContainer
        focused.unbindFromParent()
        // todo different monitor for floating windows
        focused.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        return true
    }
}
