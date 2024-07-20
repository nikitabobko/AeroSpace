import AppKit

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

        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { _ in
            resetManipulatedWithMouseIfPossible()
            // Detect clicks on desktop of different monitors
            let clickedMonitor = mouseLocation.monitorApproximation
            if clickedMonitor.activeWorkspace != focus.workspace {
                _ = refreshSession {
                    clickedMonitor.activeWorkspace.focusWorkspace()
                }
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
