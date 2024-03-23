import AppKit
import Common

struct MoveNodeToMonitorCommand: Command {
    let args: MoveNodeToMonitorCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = state.subject.windowOrNil else {
            state.stderr.append(noWindowIsFocused)
            return false
        }
        let currentMonitor = window.nodeMonitor ?? Workspace.focused.workspaceMonitor
        switch args.target.val.resolve(currentMonitor, wrapAround: args.wrapAround) {
        case .success(let targetMonitor):
            return MoveNodeToWorkspaceCommand.run(state, targetMonitor.activeWorkspace.name)
        case .failure(let msg):
            state.stderr.append(msg)
            return false
        }
    }
}
