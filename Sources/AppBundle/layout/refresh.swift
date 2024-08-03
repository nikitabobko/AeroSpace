import AppKit
import Common

/// It's one of the most important function of the whole application.
/// The function is called as a feedback response on every user input.
/// The function is idempotent.
func refreshSession<T>(startup: Bool = false, forceFocus: Bool = false, body: () -> T) -> T {
    check(Thread.current.isMainThread)
    gc()

    detectNewWindowsAndAttachThemToWorkspaces(startup: startup)

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
        if forceFocus || focusBefore != focusAfter {
            focusAfter?.nativeFocus() // syncFocusToMacOs
        }

        updateTrayText()
        normalizeLayoutReason(startup: startup)
        layoutWorkspaces()
    }
    return result
}

func refreshAndLayout(startup: Bool = false) {
    refreshSession(startup: startup, body: {})
}

func refreshModel() {
    gc()
    checkOnFocusChangedCallbacks()
    normalizeContainers()
}

private func gc() {
    // Garbage collect terminated apps and windows before working with all windows
    MacApp.garbageCollectTerminatedApps()
    // Garbage collect workspaces after apps, because workspaces contain apps.
    Workspace.garbageCollectUnusedWorkspaces()
}

func refreshObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    refreshAndLayout()
}

enum OptimalHideCorner {
    case bottomLeftCorner, bottomRightCorner
}

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
                monitors.allSatisfy({ m in !m.rect.contains(blc1) && !m.rect.contains(blc2) && !m.rect.contains(blc3) })
                ? .bottomLeftCorner
                : .bottomRightCorner
        monitorToOptimalHideCorner[monitor.rect.topLeftCorner] = corner
    }

    // to reduce flicker, first unhide visible workspaces, then hide invisible ones
    for workspace in Workspace.all where workspace.isVisible {
        // todo no need to unhide tiling windows (except for keeping hide/unhide state variables invariants)
        workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideFromCorner() } // todo as!
    }
    for workspace in Workspace.all where !workspace.isVisible {
        let corner = monitorToOptimalHideCorner[workspace.workspaceMonitor.rect.topLeftCorner] ?? .bottomRightCorner
        workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).hideInCorner(corner) } // todo as!
    }

    for monitor in monitors {
        monitor.activeWorkspace.layoutWorkspace()
    }
}

private func normalizeContainers() {
    for workspace in Workspace.all { // todo do it only for visible workspaces?
        workspace.normalizeContainers()
    }
}

private func detectNewWindowsAndAttachThemToWorkspaces(startup: Bool) {
    for app in apps {
        _ = app.detectNewWindowsAndGetAll(startup: startup)
    }
}

private func smartLayoutAtStartup() {
    let workspace = focus.workspace
    let root = workspace.rootTilingContainer
    if root.children.count <= 3 {
        root.layout = .tiles
    } else {
        root.layout = .accordion
    }
}
