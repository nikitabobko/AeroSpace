import AppKit
import Common

//public extension EnableCommand {
//    public init(targetState: EnableCmdArgs.TargetState) {
//        self.init(args: EnableCmdArgs(rawArgs: [], targetState: targetState))
//    }
//}

public struct EnableCommand: Command {
    public let args: EnableCmdArgs
    
    public func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
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
                    window.lastFloatingSize = window.getSize() ?? window.lastFloatingSize
                }
            }
            activateMode(mainModeId)
        } else {
            activateMode(nil)
            for workspace in Workspace.all {
                workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideFromCorner() } // todo as!
                workspace.layoutWorkspace() // Unhide tiling windows from corner
            }
        }
        return true
    }
}
