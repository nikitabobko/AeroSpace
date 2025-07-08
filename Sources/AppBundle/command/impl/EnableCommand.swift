import AppKit
import Common

struct EnableCommand: Command {
    let args: EnableCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let prevState = TrayMenuModel.shared.isEnabled
        let newState: Bool = switch args.targetState.val {
            case .on: true
            case .off: false
            case .toggle: !TrayMenuModel.shared.isEnabled
        }
        if newState == prevState {
            io.out((newState ? "Already enabled" : "Already disabled") +
                "Tip: use --fail-if-noop to exit with non-zero code")
            return !args.failIfNoop
        }

        TrayMenuModel.shared.isEnabled = newState
        if newState {
            for workspace in Workspace.all {
                for window in workspace.allLeafWindowsRecursive where window.isFloating {
                    window.lastFloatingSize = try await window.getAxSize() ?? window.lastFloatingSize
                }
            }
            activateMode(mainModeId)
        } else {
            activateMode(nil)
        }
        return true
    }
}
