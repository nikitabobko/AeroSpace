struct WorkspaceBackAndForthCommand: Command {
    func runWithoutLayout(state: inout FocusState) {
        check(Thread.current.isMainThread)
        guard let previousFocusedWorkspaceName else { return }
        WorkspaceCommand(workspaceName: previousFocusedWorkspaceName).runWithoutLayout(state: &state)
    }
}
