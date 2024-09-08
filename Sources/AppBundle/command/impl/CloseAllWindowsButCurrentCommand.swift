import AppKit
import Common

struct CloseAllWindowsButCurrentCommand: Command {
    let args: CloseAllWindowsButCurrentCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let focused = state.subject.windowOrNil else {
            return state.failCmd(msg: "Empty workspace")
        }
        var result = true
        guard let workspace = focused.workspace else {
            return state.failCmd(msg: "Focused window '\(focused.title)' doesn't belong to workspace")
        }
        for window in workspace.allLeafWindowsRecursive where window != focused {
            state.subject = .window(window)
            result = CloseCommand(args: args.closeArgs).run(state) && result
        }
        state.subject = .window(focused)
        return result
    }
}
