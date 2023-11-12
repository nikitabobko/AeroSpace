struct EnableCommand: Command {
    enum State: String {
        case on, off, toggle
    }

    let targetState: State

    func runWithoutLayout() {
        check(Thread.current.isMainThread)
        let isEnabled: Bool
        switch targetState {
        case .on:
            isEnabled = true
        case .off:
            isEnabled = false
        case .toggle:
            isEnabled = !TrayMenuModel.shared.isEnabled
        }
        TrayMenuModel.shared.isEnabled = isEnabled
        if isEnabled {
            activateMode(mainModeId)
        } else {
            for (_, mode) in config.modes {
                mode.deactivate()
            }
            makeAllWindowsVisibleAndRestoreSize()
        }
    }
}
