import AppKit
import Common

struct WorkspaceBackAndForthCommand: Command {
    let args = WorkspaceBackAndForthCmdArgs(rawArgs: [])

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        return prevFocusedWorkspace?.focusWorkspace() != nil
    }
}
