import AppKit
import Common

@MainActor
class GlobalObserver {
    private static var cmdRightTap: CFMachPort? = nil
    private static var cmdRightTapSource: CFRunLoopSource? = nil
    private nonisolated static func onNotif(_ notification: Notification) {
        // Third line of defence against lock screen window. See: closedWindowsCache
        // Second and third lines of defence are technically needed only to avoid potential flickering
        if (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == lockScreenAppBundleId {
            return
        }
        let notifName = notification.name.rawValue
        Task { @MainActor in
            if !TrayMenuModel.shared.isEnabled { return }
            if notifName == NSWorkspace.didActivateApplicationNotification.rawValue {
                runRefreshSession(.globalObserver(notifName), optimisticallyPreLayoutWorkspaces: true)
            } else {
                runRefreshSession(.globalObserver(notifName))
            }
        }
    }

    private nonisolated static func onHideApp(_ notification: Notification) {
        let notifName = notification.name.rawValue
        Task { @MainActor in
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try await runSession(.globalObserver(notifName), token) {
                if config.automaticallyUnhideMacosHiddenApps {
                    if let w = prevFocus?.windowOrNil,
                       w.macAppUnsafe.nsApp.isHidden,
                       // "Hide others" (cmd-alt-h) -> don't force focus
                       // "Hide app" (cmd-h) -> force focus
                       MacApp.allAppsMap.values.count(where: { $0.nsApp.isHidden }) == 1
                    {
                        // Force focus
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
            // todo reduce number of refreshSession in the callback
            //  resetManipulatedWithMouseIfPossible might call its own refreshSession
            //  The end of the callback calls refreshSession
            Task { @MainActor in
                guard let token: RunSessionGuard = .isServerEnabled else { return }
                try await resetManipulatedWithMouseIfPossible()
                let mouseLocation = mouseLocation
                let clickedMonitor = mouseLocation.monitorApproximation
                switch true {
                    // Detect clicks on desktop of different monitors
                    case clickedMonitor.activeWorkspace != focus.workspace:
                        _ = try await runSession(.globalObserverLeftMouseUp, token) {
                            clickedMonitor.activeWorkspace.focusWorkspace()
                        }
                    // Detect close button clicks for unfocused windows. Yes, kAXUIElementDestroyedNotification is that unreliable
                    //  And trigger new window detection that could be delayed due to mouseDown event
                    default:
                        runRefreshSession(.globalObserverLeftMouseUp)
                }
            }
        }

        let mask = (
            (1 << CGEventType.rightMouseDown.rawValue) |
                (1 << CGEventType.rightMouseDragged.rawValue) |
                (1 << CGEventType.rightMouseUp.rawValue) |
                (1 << CGEventType.mouseMoved.rawValue) |
                (1 << CGEventType.flagsChanged.rawValue),
        )
        if cmdRightTap == nil,
           let tap = CGEvent.tapCreate(
               tap: .cgSessionEventTap,
               place: .headInsertEventTap,
               options: .defaultTap,
               eventsOfInterest: CGEventMask(mask),
               callback: { _, type, event, _ in
                   if !TrayMenuModel.shared.isEnabled { return Unmanaged.passUnretained(event) }
                   let flags = event.flags
                   let isCmd = flags.contains(.maskCommand)
                   guard isCmd else { return Unmanaged.passUnretained(event) }
                   switch type {
                       case .rightMouseDown:
                           Task { @MainActor in await onCmdRightMouseDown() }
                           return nil
                       case .rightMouseDragged:
                           Task { @MainActor in await onCmdRightMouseDragged() }
                           return Unmanaged.passUnretained(event)
                       case .mouseMoved:
                           Task { @MainActor in await onCmdRightMouseDragged() }
                           return Unmanaged.passUnretained(event)
                       case .rightMouseUp:
                           Task { @MainActor in await onCmdRightMouseUp() }
                           return nil
                       case .flagsChanged:
                           if !isCmd {
                               Task { @MainActor in await onCmdRightMouseUp() }
                           }
                           return Unmanaged.passUnretained(event)
                       default:
                           return Unmanaged.passUnretained(event)
                   }
               },
               userInfo: nil,
           )
        {
            cmdRightTap = tap
            let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            cmdRightTapSource = src
            CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
}
