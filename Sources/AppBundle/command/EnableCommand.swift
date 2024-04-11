import AppKit
import Common

struct EnableCommand: Command {
    let args: EnableCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        let prevState = TrayMenuModel.shared.isEnabled
        let newState: Bool
        switch args.targetState.val {
        case .on:
            newState = true
        case .off:
            newState = false
        case .toggle:
            newState = !TrayMenuModel.shared.isEnabled
        }
        if newState == prevState {
            return true
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
                workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideViaEmulation() } // todo as!
                workspace.layoutWorkspace()
            }
        }
        return true
    }
}
