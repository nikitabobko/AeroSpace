struct WorkspaceBackAndForthCommand: Command {
    func runWithoutRefresh() {
        check(Thread.current.isMainThread)
        guard let previousFocusedWorkspaceName else { return }
        WorkspaceCommand(workspaceName: previousFocusedWorkspaceName).runWithoutRefresh()
    }
}
