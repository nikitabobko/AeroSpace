struct WorkspaceBackAndForthCommand: Command {
    func runWithoutLayout() {
        check(Thread.current.isMainThread)
        guard let previousFocusedWorkspaceName else { return }
        WorkspaceCommand(workspaceName: previousFocusedWorkspaceName).runWithoutLayout()
    }
}
