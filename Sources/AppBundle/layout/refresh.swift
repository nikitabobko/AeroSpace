import AppKit
import Common

/// It's one of the most important function of the whole application.
/// The function is called as a feedback response on every user input.
/// The function is idempotent.
@MainActor
func refreshSession<T>(_ event: RefreshSessionEvent, screenIsDefinitelyUnlocked: Bool, startup: Bool = false, body: () -> T) -> T {
    check(Thread.current.isMainThread)
    // refreshSessionEventForDebug = event
    // defer { refreshSessionEventForDebug = nil }
    if screenIsDefinitelyUnlocked { resetClosedWindowsCache() }
    gc()
    gcMonitors()

    detectNewAppsAndWindows(startup: startup)

    let nativeFocused = getNativeFocusedWindow(startup: startup)
    if let nativeFocused { debugWindowsIfRecording(nativeFocused) }
    updateFocusCache(nativeFocused)
    let focusBefore = focus.windowOrNil

    refreshModel()
    let result = body()
    refreshModel()

    let focusAfter = focus.windowOrNil

    if startup {
        smartLayoutAtStartup()
    }

    if TrayMenuModel.shared.isEnabled {
        if focusBefore != focusAfter {
            focusAfter?.nativeFocus() // syncFocusToMacOs
        }

        updateTrayText()
        normalizeLayoutReason(startup: startup)
        layoutWorkspaces()
    }
    return result
}

@MainActor
func refreshAndLayout(_ event: RefreshSessionEvent, screenIsDefinitelyUnlocked: Bool, startup: Bool = false) {
    refreshSession(event, screenIsDefinitelyUnlocked: screenIsDefinitelyUnlocked, startup: startup, body: {})
}

@MainActor private var havePendingRefresh = false
@MainActor private var pendingRefreshScreenIsDefinitelyUnlocked = false

@MainActor
func scheduleRefreshAndLayout(_ event: RefreshSessionEvent, screenIsDefinitelyUnlocked: Bool = false) {
    if havePendingRefresh {
        if screenIsDefinitelyUnlocked {
            pendingRefreshScreenIsDefinitelyUnlocked = true
        }
        return
    }
    havePendingRefresh = true
    pendingRefreshScreenIsDefinitelyUnlocked = screenIsDefinitelyUnlocked
    DispatchQueue.main.async { @MainActor in
        havePendingRefresh = false
        refreshSession(event, screenIsDefinitelyUnlocked: pendingRefreshScreenIsDefinitelyUnlocked, startup: false, body: {})
    }
}

@MainActor
func refreshModel() {
    gc()
    checkOnFocusChangedCallbacks()
    normalizeContainers()
}

@MainActor
private func gc() {
    // Garbage collect terminated apps and windows before working with all windows
    MacApp.garbageCollectTerminatedApps()
    gcWindows()
    // Garbage collect workspaces after apps, because workspaces contain apps.
    Workspace.garbageCollectUnusedWorkspaces()
}

@MainActor
func gcWindows() {
    // Second line of defence against lock screen. See the first line of defence: closedWindowsCache
    // Second and third lines of defence are technically needed only to avoid potential flickering
    if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == lockScreenAppBundleId { return }
    let toKill = MacWindow.allWindowsMap.filter { $0.value.axWindow.containingWindowId(signpostEvent: $0.value.app.name) == nil }
    // If all windows are "unobservable", it's highly propable that loginwindow might be still active and we are still
    // recovering from unlock
    if toKill.count == MacWindow.allWindowsMap.count { return }
    for window in toKill {
        window.value.garbageCollect(skipClosedWindowsCache: false)
    }
}

func refreshObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    check(Thread.isMainThread)
    let notif = notif as String
    MainActor.assumeIsolated {
        scheduleRefreshAndLayout(.ax(notif), screenIsDefinitelyUnlocked: false)
    }
}

enum OptimalHideCorner {
    case bottomLeftCorner, bottomRightCorner
}

@MainActor
private func layoutWorkspaces() {
    let monitors = monitors
    var monitorToOptimalHideCorner: [CGPoint: OptimalHideCorner] = [:]
    for monitor in monitors {
        let xOff = monitor.width * 0.1
        let yOff = monitor.height * 0.1
        // brc = bottomRightCorner
        let brc1 = monitor.rect.bottomRightCorner + CGPoint(x: 2, y: -yOff)
        let brc2 = monitor.rect.bottomRightCorner + CGPoint(x: -xOff, y: 2)
        let brc3 = monitor.rect.bottomRightCorner + CGPoint(x: 2, y: 2)

        // blc = bottomLeftCorner
        let blc1 = monitor.rect.bottomLeftCorner + CGPoint(x: -2, y: -yOff)
        let blc2 = monitor.rect.bottomLeftCorner + CGPoint(x: xOff, y: 2)
        let blc3 = monitor.rect.bottomLeftCorner + CGPoint(x: -2, y: 2)

        let corner: OptimalHideCorner =
            monitors.contains(where: { m in m.rect.contains(brc1) || m.rect.contains(brc2) || m.rect.contains(brc3) }) &&
            monitors.allSatisfy { m in !m.rect.contains(blc1) && !m.rect.contains(blc2) && !m.rect.contains(blc3) }
            ? .bottomLeftCorner
            : .bottomRightCorner
        monitorToOptimalHideCorner[monitor.rect.topLeftCorner] = corner
    }

    // to reduce flicker, first unhide visible workspaces, then hide invisible ones
    for monitor in monitors {
        let workspace = monitor.activeWorkspace
        workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideFromCorner() } // todo as!
        workspace.layoutWorkspace()
    }
    for workspace in Workspace.all where !workspace.isVisible {
        let corner = monitorToOptimalHideCorner[workspace.workspaceMonitor.rect.topLeftCorner] ?? .bottomRightCorner
        workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).hideInCorner(corner) } // todo as!
    }
}

@MainActor
private func normalizeContainers() {
    // Can't do it only for visible workspace because most of the commands support --window-id and --workspace flags
    for workspace in Workspace.all {
        workspace.normalizeContainers()
    }
}

@MainActor
private func detectNewAppsAndWindows(startup: Bool) {
    for app in apps {
        app.detectNewWindows(startup: startup)
    }
}

@MainActor
private func smartLayoutAtStartup() {
    let workspace = focus.workspace
    let root = workspace.rootTilingContainer
    if root.children.count <= 3 {
        root.layout = .tiles
    } else {
        root.layout = .accordion
    }
}
