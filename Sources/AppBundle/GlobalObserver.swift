import AppKit

class GlobalObserver {
    @objc private static func onNsWorkspaceNotification() {
        refreshAndLayout()
    }

    @objc private static func onHideApp() {
        refreshSession(body: {
            if TrayMenuModel.shared.isEnabled && config.automaticallyUnhideMacosHiddenApps {
                if let w = prevFocus?.windowOrNil,
                        w.macAppUnsafe.nsApp.isHidden,
                        // "Hide others" (cmd-alt-h) -> don't force focus
                        // "Hide app" (cmd-h) -> force focus
                        MacApp.allAppsMap.values.filter({ $0.nsApp.isHidden }).count == 1 {
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
            selector: name == NSWorkspace.didHideApplicationNotification
                ? #selector(onHideApp)
                : #selector(onNsWorkspaceNotification),
            name: name,
            object: nil
        )
    }
}
