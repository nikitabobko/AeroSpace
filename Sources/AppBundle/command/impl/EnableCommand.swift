import AppKit
import Common

struct EnableCommand: Command {
    let args: EnableCmdArgs

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
        if newState && args.noPreserveWindows {
            io.out("--no-preserve-windows doesn't mean anything when aerospace is enabled")
            return false
        }

        TrayMenuModel.shared.isEnabled = newState
        if newState {
            TrayMenuModel.shared.shouldPreserveWindowsOnDisable = true
            for workspace in Workspace.all {
                for window in workspace.allLeafWindowsRecursive where window.isFloating {
                    window.lastFloatingSize = try await window.getAxSize() ?? window.lastFloatingSize
                }
            }
            activateMode(mainModeId)
        } else {
            TrayMenuModel.shared.shouldPreserveWindowsOnDisable = !args.noPreserveWindows
            activateMode(nil)
        }
        return true
    }
}
