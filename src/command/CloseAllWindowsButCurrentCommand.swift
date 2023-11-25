class CloseAllWindowsButCurrentCommand: Command {
    func _run(_ subject: inout CommandSubject, _ index: Int, _ commands: [any Command]) {
        check(Thread.current.isMainThread)
        guard let focused = subject.windowOrNil else { return }
        for window in focused.workspace.allLeafWindowsRecursive {
            if window != focused {
                window.close()
                (window as! MacWindow).garbageCollect()
            }
        }
    }
}
