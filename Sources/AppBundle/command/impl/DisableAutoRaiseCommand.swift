import AppKit
import Common

struct DisableAutoRaiseCommand: Command {
    let args: DisableAutoRaiseCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> BinaryExitCode {
        // True noop only when the bridge is already stopped AND the sticky
        // runtime-disabled flag is already set. If the bridge is off because
        // `config.enabled = false`, calling stop() still matters — it sets the
        // sticky flag so a later config reload with `enabled = true` won't
        // silently re-enable.
        let isTrueNoop = AutoRaiseController.isNoopForDisableCommand
        AutoRaiseController.stop()
        if isTrueNoop {
            switch args.failIfNoop {
                case true: return .fail
                case false:
                    return .succ(io.err("auto-raise is already disabled. Tip: use --fail-if-noop to exit with non-zero code"))
            }
        }
        return .succ
    }
}
