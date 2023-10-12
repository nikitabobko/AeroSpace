class GlobalObserver {
    @objc private static func action() {
        refresh()
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
            resetResizeWithMouseIfPossible()
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
