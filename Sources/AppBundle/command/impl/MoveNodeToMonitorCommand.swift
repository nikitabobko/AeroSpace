import AppKit
import Common

struct MoveNodeToMonitorCommand: Command {
    let args: MoveNodeToMonitorCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        guard let currentMonitor = window.nodeMonitor else {
            return .fail(io.err(windowIsntPartOfTree(window)))
        }
        switch args.target.val.resolve(currentMonitor, wrapAround: args.wrapAround) {
            case .success(let targetMonitor):
                let targetWs = targetMonitor.activeWorkspace
                let index = true == args.target.val.directionOrNil
                    .map { dir in dir.isPositive && targetWs.rootTilingContainer.orientation == dir.orientation }
                    ? 0
                    : INDEX_BIND_LAST
                return moveWindowToWorkspace(
                    window,
                    targetWs,
                    io,
                    focusFollowsWindow: args.focusFollowsWindow,
                    failIfNoop: args.failIfNoop,
                    index: index,
                )
            case .failure(let msg):
                return .fail(io.err(msg))
        }
    }
}

func windowIsntPartOfTree(_ window: Window) -> String {
    "Window \(window.windowId) is not part of tree (minimized or hidden)"
}
