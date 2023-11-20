class CloseAllWindowsButCurrentCommand: Command {
    func runWithoutLayout(subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        guard let focused = subject.windowOrNil else { return }
        for window in focused.workspace.allLeafWindowsRecursive {
            if window != focused {
                window.close()
            }
        }
    }
}