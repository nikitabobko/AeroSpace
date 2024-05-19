import AppKit
import Common

struct WorkspaceBackAndForthCommand: Command {
    let args = WorkspaceBackAndForthCmdArgs(rawArgs: [])

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let previousFocusedWorkspaceName else { return false }
        return WorkspaceCommand.run(state, previousFocusedWorkspaceName)
    }
}
