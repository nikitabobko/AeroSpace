import Common

struct CloseAllWindowsButCurrentCommand: Command {
    let args = CloseAllWindowsButCurrentCmdArgs()

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let focused = state.subject.windowOrNil else {
            state.stdout.append("Empty workspace")
            return false
        }
        var result = true
        for window in focused.workspace.allLeafWindowsRecursive {
            if window != focused {
                result = CloseCommand().run(state) && result
            }
        }
        return result
    }
}
