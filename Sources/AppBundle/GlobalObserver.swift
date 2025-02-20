import AppKit

class GlobalObserver {
    private static func onNotif(_ notification: Notification) {
        // Third line of defence against lock screen window. See: closedWindowsCache
        // Second and third lines of defence are technically needed only to avoid potential flickering
        if (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == lockScreenAppBundleId {
            return
        }
        refreshAndLayout(.globalObserver(notification.name.rawValue), screenIsDefinitelyUnlocked: false)
    }

    private static func onHideApp(_ notification: Notification) {
        refreshSession(.globalObserver(notification.name.rawValue), screenIsDefinitelyUnlocked: false) {
            if TrayMenuModel.shared.isEnabled && config.automaticallyUnhideMacosHiddenApps {
                if let w = prevFocus?.windowOrNil,
                   w.macAppUnsafe.nsApp.isHidden,
                   // "Hide others" (cmd-alt-h) -> don't force focus
                   // "Hide app" (cmd-h) -> force focus
                   MacApp.allAppsMap.values.filter({ $0.nsApp.isHidden }).count == 1
                {
                    if let identifier = w.macAppUnsafe.nsApp.bundleIdentifier,
                       config.automaticallyUnhideMacosHiddenAppsExceptions.contains(identifier)
                    {}
                    else {
                        // Force focus
                        _ = w.focusWindow()
                        _ = w.nativeFocus()
                    }
                }
                for app in MacApp.allAppsMap.values {
                    if let identifier = app.nsApp.bundleIdentifier,
                       config.automaticallyUnhideMacosHiddenAppsExceptions.contains(identifier)
                    {
                        continue
                    }
                    app.nsApp.unhide()
                }
            }
        }
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

        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { _ in
            // todo reduce number of refreshSession in the callback
            //  resetManipulatedWithMouseIfPossible might call its own refreshSession
            //  The end of the callback calls refreshSession
            resetClosedWindowsCache()
            resetManipulatedWithMouseIfPossible()
            let mouseLocation = mouseLocation
            let clickedMonitor = mouseLocation.monitorApproximation
            switch () {
                // Detect clicks on desktop of different monitors
                case _ where clickedMonitor.activeWorkspace != focus.workspace:
                    _ = refreshSession(.globalObserverLeftMouseUp, screenIsDefinitelyUnlocked: true) {
                        clickedMonitor.activeWorkspace.focusWorkspace()
                    }
                // Detect close button clicks for unfocused windows. Yes, kAXUIElementDestroyedNotification is that unreliable
                //  And trigger new window detection that could be delayed due to mouseDown event
                default:
                    refreshAndLayout(.globalObserverLeftMouseUp, screenIsDefinitelyUnlocked: true)
            }
        }
    }
}
