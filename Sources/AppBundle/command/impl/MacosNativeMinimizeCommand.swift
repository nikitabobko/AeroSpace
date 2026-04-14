import AppKit
import Common

/// See: MacosNativeFullscreenCommand. Problem ID-B6E178F2
struct MacosNativeMinimizeCommand: Command {
    let args: MacosNativeMinimizeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> BinaryExitCode {
        // resolveTargetOrReportError on already minimized windows will always fail
        // It would be easier if minimized windows were part of the workspace in tree hierarchy
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        let newState: Bool = try await !window.isMacosMinimized
        window.asMacWindow().setNativeMinimized(newState)
        if newState { // minimize
            window.bind(to: macosMinimizedWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
            return .succ
        } else { // unminimize
            return .fail(io.err("The command is uncapable of unminimizing windows yet. Sorry")) // dead code. should never be possible, see the comment above
        }
    }
}
