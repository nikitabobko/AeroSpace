struct WorkspaceCommand : Command {
    let workspaceName: String

    func runWithoutLayout(subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        let workspace = Workspace.get(byName: workspaceName)
        // todo drop anyLeafWindowRecursive. It must not be necessary
        if let window = workspace.mostRecentWindow ?? workspace.anyLeafWindowRecursive { // switch to not empty workspace
            subject = .window(window)
        } else { // switch to empty workspace
            check(workspace.isEffectivelyEmpty)
            subject = .emptyWorkspace(workspaceName)
        }
        check(workspace.monitor.setActiveWorkspace(workspace))
        focusedWorkspaceName = workspace.name
    }
}
