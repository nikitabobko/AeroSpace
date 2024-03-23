import Common

struct CloseAllWindowsButCurrentCommand: Command {
    let args: CloseAllWindowsButCurrentCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let focused = state.subject.windowOrNil else {
            state.stderr.append("Empty workspace")
            return false
        }
        var result = true
        guard let workspace = focused.workspace else {
            state.stderr.append("Focused window '\(focused.title)' doesn't belong to workspace")
            return false
        }
        for window in workspace.allLeafWindowsRecursive {
            if window != focused {
                state.subject = .window(window)
                result = CloseCommand(args: args.closeArgs).run(state) && result
            }
        }
        state.subject = .window(focused)
        return result
    }
}
