import AppKit

class GlobalObserver {
    private static func onNotif(_ notification: Notification) {
        refreshAndLayout()
    }

    private static func onHideApp(_ notification: Notification) {
        refreshSession(body: {
            if TrayMenuModel.shared.isEnabled && config.automaticallyUnhideMacosHiddenApps {
                if let w = prevFocus?.windowOrNil,
                   w.macAppUnsafe.nsApp.isHidden,
                   // "Hide others" (cmd-alt-h) -> don't force focus
                   // "Hide app" (cmd-h) -> force focus
                   MacApp.allAppsMap.values.filter({ $0.nsApp.isHidden }).count == 1
                {
                    // Force focus
                    _ = w.focusWindow()
                    _ = w.nativeFocus()
                }
                for app in MacApp.allAppsMap.values {
                    app.nsApp.unhide()
                }
            }
        })
    }

    static func initObserver() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main, using: onNotif)
        nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main, using: onNotif)
        nc.addObserver(forName: NSWorkspace.didHideApplicationNotification, object: nil, queue: .main, using: onHideApp)
        nc.addObserver(forName: NSWorkspace.didUnhideApplicationNotification, object: nil, queue: .main, using: onNotif)
        nc.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main, using: onNotif)
        nc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main, using: onNotif)
        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main, using: onNotif)

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
}
