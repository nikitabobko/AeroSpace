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
            return switch args.failIfNoop {
                case true: .fail
                case false:
                    .succ(io.err(
                        newState
                            ? "Already enabled. Tip: use --fail-if-noop to exit with non-zero code"
                            : "Already disabled. Tip: use --fail-if-noop to exit with non-zero code",
                    ))
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
        } else {
            try await activateMode(nil)
        }
        return .succ
    }
}
