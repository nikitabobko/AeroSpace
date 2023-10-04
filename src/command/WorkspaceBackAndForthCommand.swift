struct WorkspaceBackAndForthCommand: Command {
    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        guard let previousFocusedWorkspaceName else { return }
        WorkspaceCommand(workspaceName: previousFocusedWorkspaceName).runWithoutRefresh()
    }
}
