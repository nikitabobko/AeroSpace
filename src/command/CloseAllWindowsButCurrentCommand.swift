import Common

struct CloseAllWindowsButCurrentCommand: Command {
    let args = CloseAllWindowsButCurrentCmdArgs()

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let focused = state.subject.windowOrNil else {
            state.stderr.append("Empty workspace")
            return false
        }
        var result = true
        for window in focused.workspace.allLeafWindowsRecursive {
            if window != focused {
                state.subject = .window(window)
                result = CloseCommand().run(state) && result
            }
        }
        state.subject = .window(focused)
        return result
    }
}
