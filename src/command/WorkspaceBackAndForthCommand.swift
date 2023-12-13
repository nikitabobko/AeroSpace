struct WorkspaceBackAndForthCommand: Command {
    func _run(_ subject: inout CommandSubject, _ index: Int, _ commands: [any Command]) {
        check(Thread.current.isMainThread)
        guard let previousFocusedWorkspaceName else { return }
        WorkspaceCommand(args: WorkspaceCmdArgs(
            target: .workspaceName(name: previousFocusedWorkspaceName, autoBackAndForth: false)
        )).run(&subject)
    }
}
