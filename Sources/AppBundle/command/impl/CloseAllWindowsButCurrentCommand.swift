import AppKit
import Common

struct CloseAllWindowsButCurrentCommand: Command {
    let args: CloseAllWindowsButCurrentCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let focused = target.windowOrNil else {
            return io.err("Empty workspace")
        }
        guard let workspace = focused.nodeWorkspace else {
            return io.err("Focused window '\(focused.windowId)' doesn't belong to workspace")
        }
        var result = true
        for window in workspace.allLeafWindowsRecursive where window != focused {
            result = try await CloseCommand(args: args.closeArgs).run(env.copy(\.windowId, window.windowId), io) && result
        }
        return result
    }
}
