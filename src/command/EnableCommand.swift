struct EnableCommand: Command {
    enum State: String {
        case on, off, toggle
    }

    let targetState: State

    func runWithoutLayout(subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        let prevState = TrayMenuModel.shared.isEnabled
        let newState: Bool
        switch targetState {
        case .on:
            newState = true
        case .off:
            newState = false
        case .toggle:
            newState = !TrayMenuModel.shared.isEnabled
        }
        if newState == prevState {
            return
        }

        TrayMenuModel.shared.isEnabled = newState
        if newState {
            for app in apps {
                for window in app.windows {
                    window.lastFloatingSize = window.getSize() ?? window.lastFloatingSize
                }
            }
            activateMode(mainModeId)
        } else {
            for (_, mode) in config.modes {
                mode.deactivate()
            }
            makeAllWindowsVisibleAndRestoreSize()
        }
    }
}
