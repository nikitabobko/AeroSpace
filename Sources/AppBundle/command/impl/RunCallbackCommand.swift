import AppKit
import Common

struct RunCallbackCommand: Command {
    let args: RunCallbackCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Int32ExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        switch args.callback.val {
            case .onWindowDetected where args.forEveryWindow:
                var exitCode = Int32ExitCode.succ
                for window in MacWindow.allWindows {
                    exitCode = try await onWindowDetected(env, io, window)
                }
                return exitCode
            case .onWindowDetected:
                guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
                return try await onWindowDetected(env, io, window)
            case .onFocusChanged:
                return try await onFocusChanged(env, io, target)
            case .onFocusedMonitorChanged:
                return try await onFocusedMonitorChanged(env, io, target)
        }
    }
}
