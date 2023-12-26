import Common

struct CloseAllWindowsButCurrentCommand: Command {
    let info: CmdStaticInfo = CloseAllWindowsButCurrentCmdArgs.info

    func _run(_ subject: inout CommandSubject, _ stdout: inout [String]) -> Bool {
        check(Thread.current.isMainThread)
        guard let focused = subject.windowOrNil else {
            stdout.append("Empty workspace")
            return false
        }
        var result = true
        for window in focused.workspace.allLeafWindowsRecursive {
            if window != focused {
                result = CloseCommand().run(&subject, &stdout) && result
            }
        }
        return result
    }
}
