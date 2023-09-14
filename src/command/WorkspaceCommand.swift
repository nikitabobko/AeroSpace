struct WorkspaceCommand : Command {
    let workspaceName: String

    func run() {
        switchToWorkspace(Workspace.get(byName: workspaceName))
    }
}
