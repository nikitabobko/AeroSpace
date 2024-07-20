import AppKit
import Common

struct FocusBackAndForthCommand: Command {
    let args: FocusBackAndForthCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        if let prevFocus {
            return setFocus(to: prevFocus)
        } else {
            return false
        }
    }
}
