import AppKit
import Common

enum GlobalObserver {
    private static func onNotif(_ notification: Notification) {
        // Third line of defence against lock screen window. See: closedWindowsCache
        // Second and third lines of defence are technically needed only to avoid potential flickering
        if (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == lockScreenAppBundleId {
            return
        }
        let notifName = notification.name.rawValue
        Task.startUnstructured { @MainActor in
            if !TrayMenuModel.shared.isEnabled { return }
            if notifName == NSWorkspace.didActivateApplicationNotification.rawValue {
                scheduleCancellableCompleteRefreshSession(.globalObserver(notifName), optimisticallyPreLayoutWorkspaces: true)
            } else {
                scheduleCancellableCompleteRefreshSession(.globalObserver(notifName))
            }
        }
    }

    private static func onHideApp(_ notification: Notification) {
        let notifName = notification.name.rawValue
        Task.startUnstructured { @MainActor in
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try await runLightSession(.globalObserver(notifName), token) {
                if config.automaticallyUnhideMacosHiddenApps {
                    if let w = prevFocus?.windowOrNil,
                       w.macAppUnsafe.nsApp.isHidden,
                       // "Hide others" (cmd-alt-h) -> don't force globalFocus
                       // "Hide app" (cmd-h) -> force globalFocus
                       MacApp.allAppsMap.values.count(where: { $0.nsApp.isHidden }) == 1
                    {
                        // Force globalFocus
                        _ = w.focusWindow()
                        w.nativeFocus()
                    }
                    for app in MacApp.allAppsMap.values {
                        app.nsApp.unhide()
                    }
                }
            }
        }
    }

    @MainActor
    static func initObserver() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main, using: onNotif)
        nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main, using: onNotif)
        nc.addObserver(forName: NSWorkspace.didHideApplicationNotification, object: nil, queue: .main, using: onHideApp)
        nc.addObserver(forName: NSWorkspace.didUnhideApplicationNotification, object: nil, queue: .main, using: onNotif)
        nc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main, using: onNotif)
        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main, using: onNotif)

        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { _ in
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            // todo reduce number of refreshSession in the callback
            //  resetManipulatedWithMouseIfPossible might call its own refreshSession
            //  The end of the callback calls refreshSession
            Task.startUnstructured { @MainActor in
                try await resetManipulatedWithMouseIfPossible()
                let mouseLocation = mouseLocation
                let clickedMonitor = mouseLocation.monitorApproximation
                let shouldCheckDesktopClick = clickedMonitor.visibleRect.contains(mouseLocation) && clickedMonitor.visibleWorkspace != globalFocus.workspace
                let desktopClick = shouldCheckDesktopClick && isClickOnDesktop(mouseLocation: mouseLocation)
                if let workspace = workspaceToFocusAfterLeftMouseUp(
                    mouseLocation: mouseLocation,
                    clickedMonitor: clickedMonitor,
                    isClickOnDesktop: desktopClick,
                ) {
                    // Detect clicks on desktop of different monitors
                    _ = try await runLightSession(.globalObserverLeftMouseUp, token) {
                        workspace.focusWorkspace()
                    }
                } else {
                    // Detect close button clicks for unfocused windows. Yes, kAXUIElementDestroyedNotification is that unreliable
                    //  And trigger new window detection that could be delayed due to mouseDown event
                    scheduleCancellableCompleteRefreshSession(.globalObserverLeftMouseUp)
                }
            }
        }
    }
}

@MainActor
func workspaceToFocusAfterLeftMouseUp(mouseLocation: Point, clickedMonitor: MonitorInfo, isClickOnDesktop: Bool) -> Workspace? {
    guard clickedMonitor.visibleRect.contains(mouseLocation) else { return nil }
    guard isClickOnDesktop else { return nil }
    let clickedWorkspace = clickedMonitor.visibleWorkspace
    return clickedWorkspace == globalFocus.workspace ? nil : clickedWorkspace
}

func isClickOnDesktop(mouseLocation: Point) -> Bool {
    guard let windowInfos = copyOnScreenNonDesktopWindowInfos() else { return false }
    return isClickOnDesktop(mouseLocation: mouseLocation, windowInfos: windowInfos)
}

func isClickOnDesktop(mouseLocation: Point, windowInfos: [NSDictionary]) -> Bool {
    !windowInfos.contains { windowInfo in
        let alpha = (windowInfo[kCGWindowAlpha] as? NSNumber)?.doubleValue ?? 1
        guard alpha > 0 else { return false }
        guard let boundsDict = windowInfo[kCGWindowBounds] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
        else { return false }
        return bounds.contains(mouseLocation.asCGPoint)
    }
}

private func copyOnScreenNonDesktopWindowInfos() -> [NSDictionary]? {
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    guard let cfArray = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [CFDictionary] else { return nil }
    return cfArray.map { $0 as NSDictionary }
}
