struct CloseCommand: Command {
    let info: CmdStaticInfo = CloseCmdArgs.info

    func _run(_ subject: inout CommandSubject, _ stdout: inout String) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = subject.windowOrNil else {
            stdout += "Empty workspace\n"
            return false
        }
        if window.close() {
            (window as! MacWindow).garbageCollect()
            if let focusedWindow {
                subject = .window(focusedWindow)
            } else {
                subject = .emptyWorkspace(focusedWorkspaceName)
            }
            return true
        } else {
            stdout += "Can't close the window. Probably it doesn't have close button\n"
            return false
        }
    }
}
