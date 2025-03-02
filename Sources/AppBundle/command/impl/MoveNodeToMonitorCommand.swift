import AppKit
import Common

struct MoveNodeToMonitorCommand: Command {
    let args: MoveNodeToMonitorCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let window = target.windowOrNil else {
            return io.err(noWindowIsFocused)
        }
        guard let currentMonitor = window.nodeMonitor else {
            return io.err(windowIsntPartOfTree(window))
        }
        switch args.target.val.resolve(currentMonitor, wrapAround: args.wrapAround) {
            case .success(let targetMonitor):
                if let wName = WorkspaceName.parse(targetMonitor.activeWorkspace.name).getOrNil(appendErrorTo: &io.stderr) {
                    let moveNodeToWorkspace = args.moveNodeToWorkspace.copy(\.target, .initialized(.direct(wName)))
                    return MoveNodeToWorkspaceCommand(args: moveNodeToWorkspace).run(env, io)
                } else {
                    return false
                }
            case .failure(let msg):
                return io.err(msg)
        }
    }
}

func windowIsntPartOfTree(_ window: Window) -> String {
    "Window \(window.windowId) is not part of tree (minimized or hidden)"
}
