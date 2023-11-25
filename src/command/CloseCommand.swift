class CloseCommand: Command {
    func _run(_ subject: inout CommandSubject, _ index: Int, _ commands: [any Command]) {
        check(Thread.current.isMainThread)
        guard let window = subject.windowOrNil else { return }
        window.close()
        (window as! MacWindow).garbageCollect()
        if let focusedWindow {
            subject = .window(focusedWindow)
        } else {
            subject = .emptyWorkspace(focusedWorkspaceName)
        }
    }
}
