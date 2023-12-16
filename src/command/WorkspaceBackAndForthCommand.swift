struct WorkspaceBackAndForthCommand: Command {
    func _run(_ subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        guard let previousFocusedWorkspaceName else { return }
        WorkspaceCommand(args: WorkspaceCmdArgs(
            target: .workspaceName(name: previousFocusedWorkspaceName, autoBackAndForth: false)
        )).run(&subject)
    }
}
