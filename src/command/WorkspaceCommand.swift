struct WorkspaceCommand : Command {
    let workspaceName: String

    func run() async {
        precondition(Thread.current.isMainThread)
        switchToWorkspace(Workspace.get(byName: workspaceName))
    }
}
