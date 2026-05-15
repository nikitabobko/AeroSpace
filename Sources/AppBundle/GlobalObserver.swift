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
        Task { @MainActor in
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
        Task { @MainActor in
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try await runLightSession(.globalObserver(notifName), token) {
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
    fileprivate static func joinDraggedIntoTarget(
        dragged: Window,
        target: Window,
        targetParent: TilingContainer,
        cfg: MouseDragJoinConfig,
        mouseLocation: CGPoint,
    ) {
        let after: Bool = if let rect = target.lastAppliedLayoutPhysicalRect {
            mouseLocation.getProjection(targetParent.orientation) >= rect.center.getProjection(targetParent.orientation)
        } else {
            true
        }
        dragged.unbindFromParent()
        let targetIndex = target.ownIndex.orDie()
        dragged.bind(to: targetParent, adaptiveWeight: WEIGHT_AUTO, index: after ? targetIndex + 1 : targetIndex)
        targetParent.layout = cfg.layout
        targetParent.changeOrientation(cfg.orientation)
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

        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { event in
            // todo reduce number of refreshSession in the callback
            //  resetManipulatedWithMouseIfPossible might call its own refreshSession
            //  The end of the callback calls refreshSession
            let modifierFlags = event.modifierFlags
            Task { @MainActor in
                guard let token: RunSessionGuard = .isServerEnabled else { return }
                let draggedWindowId = currentlyManipulatedWithMouseWindowId
                try await resetManipulatedWithMouseIfPossible()
                let mouseLocation = mouseLocation
                if let cfg = config.mouseDragJoin,
                   modifierFlags.contains(cfg.modifier),
                   let id = draggedWindowId,
                   let dragged = Window.get(byId: id)
                {
                    let targetWorkspace = mouseLocation.monitorApproximation.activeWorkspace
                    if let target = mouseLocation.findIn(tree: targetWorkspace.rootTilingContainer, virtual: false)?.takeIf({ $0 != dragged }),
                       let targetParent = target.parent as? TilingContainer
                    {
                        _ = try await runLightSession(.globalObserverLeftMouseUp, token) {
                            joinDraggedIntoTarget(dragged: dragged, target: target, targetParent: targetParent, cfg: cfg, mouseLocation: mouseLocation)
                        }
                        return
                    }
                }
                let clickedMonitor = mouseLocation.monitorApproximation
                switch true {
                    // Detect clicks on desktop of different monitors
                    case clickedMonitor.activeWorkspace != focus.workspace:
                        _ = try await runLightSession(.globalObserverLeftMouseUp, token) {
                            clickedMonitor.activeWorkspace.focusWorkspace()
                        }
                    // Detect close button clicks for unfocused windows. Yes, kAXUIElementDestroyedNotification is that unreliable
                    //  And trigger new window detection that could be delayed due to mouseDown event
                    default:
                        scheduleCancellableCompleteRefreshSession(.globalObserverLeftMouseUp)
                }
            }
        }
    }
}
