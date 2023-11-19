struct WorkspaceCommand : Command {
    let workspaceName: String

    func runWithoutLayout(state: inout FocusState) {
        check(Thread.current.isMainThread)
        let workspace = Workspace.get(byName: workspaceName)
        // todo drop anyLeafWindowRecursive. It must not be necessary
        if let window = workspace.mostRecentWindow ?? workspace.anyLeafWindowRecursive { // switch to not empty workspace
            focusedWorkspaceSourceOfTruth = .macOs
            state = .windowIsFocused(window)
        } else { // switch to empty workspace
            check(workspace.isEffectivelyEmpty)
            focusedWorkspaceSourceOfTruth = .ownModel
            state = .emptyWorkspaceIsFocused(workspaceName)
        }
        check(workspace.monitor.setActiveWorkspace(workspace))
        focusedWorkspaceName = workspace.name
    }
}
