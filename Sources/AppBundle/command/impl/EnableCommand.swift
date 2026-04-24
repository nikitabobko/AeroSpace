import AppKit
import Common

struct EnableCommand: Command {
    let args: EnableCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> BinaryExitCode {
        let prevState = TrayMenuModel.shared.isEnabled
        let newState: Bool = switch args.targetState.val {
            case .on: true
            case .off: false
            case .toggle: !TrayMenuModel.shared.isEnabled
        }
        if newState == prevState {
            switch args.failIfNoop {
                case true: return .fail
                case false:
                    let msg = newState
                        ? "Already enabled. Tip: use --fail-if-noop to exit with non-zero code"
                        : "Already disabled. Tip: use --fail-if-noop to exit with non-zero code"
                    return .succ(io.err(msg))
            }
        }

        TrayMenuModel.shared.isEnabled = newState
        if newState {
            for workspace in Workspace.all {
                for window in workspace.allLeafWindowsRecursive where window.isFloating {
                    window.lastFloatingSize = try await window.getAxSize() ?? window.lastFloatingSize
                }
            }
            try await activateMode(mainModeId)
            // Resume hover-raise if a prior `enable off` paused it. A sticky
            // runtime-disable set via `disable-auto-raise` is preserved inside
            // the controller — resumeFromMaster is a no-op in that case.
            AutoRaiseController.resumeFromMaster()
        } else {
            // Pause hover-raise so mouse-moved events don't keep mutating
            // focus while window management is disabled. The pause captures
            // the current running state so the matching `enable on` restores
            // it; `disable-auto-raise` sticky state is untouched.
            AutoRaiseController.pauseForMaster()
            try await activateMode(nil)
        }
        return .succ
    }
}
