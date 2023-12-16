class CloseCommand: Command {
    func _run(_ subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        guard let window = subject.windowOrNil else { return }
        if window.close() {
            (window as! MacWindow).garbageCollect()
            if let focusedWindow {
                subject = .window(focusedWindow)
            } else {
                subject = .emptyWorkspace(focusedWorkspaceName)
            }
        }
    }
}
