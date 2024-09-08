import AppKit
import Common

struct MoveNodeToMonitorCommand: Command {
    let args: MoveNodeToMonitorCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = state.subject.windowOrNil else {
            return state.failCmd(msg: noWindowIsFocused)
        }
        guard let currentMonitor = window.nodeMonitor else {
            return state.failCmd(msg: windowIsntPartOfTree(window))
        }
        return switch args.target.val.resolve(currentMonitor, wrapAround: args.wrapAround) {
            case .success(let targetMonitor): MoveNodeToWorkspaceCommand.run(state, targetMonitor.activeWorkspace.name)
            case .failure(let msg): state.failCmd(msg: msg)
        }
    }
}

func windowIsntPartOfTree(_ window: Window) -> String {
    "Window \(window.windowId) is not part of tree (minimized or hidden)"
}
