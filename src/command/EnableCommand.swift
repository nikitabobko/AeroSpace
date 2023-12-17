import Common

struct EnableCommand: Command {
    let info: CmdStaticInfo = EnableCmdArgs.info
    let args: EnableCmdArgs

    func _run(_ subject: inout CommandSubject, _ stdout: inout String) -> Bool {
        check(Thread.current.isMainThread)
        let prevState = TrayMenuModel.shared.isEnabled
        let newState: Bool
        switch args.targetState {
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
                for window in workspace.allLeafWindowsRecursive {
                    if window.isFloating {
                        window.lastFloatingSize = window.getSize() ?? window.lastFloatingSize
                    }
                }
            }
            activateMode(mainModeId)
        } else {
            for (_, mode) in config.modes {
                mode.deactivate()
            }
            for workspace in Workspace.all {
                workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideViaEmulation() } // todo as!
                workspace.layoutWorkspace()
            }
        }
        return true
    }
}
