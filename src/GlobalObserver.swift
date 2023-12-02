class GlobalObserver {
    @objc private static func action() {
        refreshAndLayout()
    }

    static func initObserver() {
        subscribe(NSWorkspace.didLaunchApplicationNotification)
        subscribe(NSWorkspace.didActivateApplicationNotification)
        subscribe(NSWorkspace.didHideApplicationNotification)
        subscribe(NSWorkspace.didUnhideApplicationNotification)
        subscribe(NSWorkspace.didDeactivateApplicationNotification)
        subscribe(NSWorkspace.activeSpaceDidChangeNotification)
        subscribe(NSWorkspace.didTerminateApplicationNotification)

        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { event in
            resetManipulatedWithMouseIfPossible()
            // Detect clicks on desktop of different monitors
            let focusedMonitor = mouseLocation.monitorApproximation
            if monitors.count > 1 &&
                   focusedMonitor.rect.topLeftCorner != Workspace.focused.monitor.rect.topLeftCorner &&
                   getNativeFocusedWindow(startup: false) == nil {
                setFocusSourceOfTruth(.ownModel, startup: false)
                focusedWorkspaceName = focusedMonitor.activeWorkspace.name
                refreshAndLayout()
            }
        }
    }

    private static func subscribe(_ name: NSNotification.Name) {
        NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(action),
                name: name,
                object: nil
        )
    }
}
