struct WorkspaceBackAndForthCommand: Command {
    func runWithoutLayout(subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        guard let previousFocusedWorkspaceName else { return }
        WorkspaceCommand(workspaceName: previousFocusedWorkspaceName).runWithoutLayout(subject: &subject)
    }
}
