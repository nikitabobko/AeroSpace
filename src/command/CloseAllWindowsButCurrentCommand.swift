class CloseAllWindowsButCurrentCommand: Command {
    func _run(_ subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        guard let focused = subject.windowOrNil else { return }
        for window in focused.workspace.allLeafWindowsRecursive {
            if window != focused {
                if window.close() {
                    (window as! MacWindow).garbageCollect()
                }
            }
        }
    }
}
