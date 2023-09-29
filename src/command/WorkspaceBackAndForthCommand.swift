struct WorkspaceBackAndForthCommand: Command {
    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        guard let previousWorkspaceName else { return }
        WorkspaceCommand(workspaceName: previousWorkspaceName).runWithoutRefresh()
    }
}
