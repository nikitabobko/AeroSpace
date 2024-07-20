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

private func layoutWorkspaces() {
    // to reduce flicker, first unhide visible workspaces, then hide invisible ones
    for workspace in Workspace.all where workspace.isVisible {
        // todo no need to unhide tiling windows (except for keeping hide/unhide state variables invariants)
        workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideViaEmulation() } // todo as!
    }
    for workspace in Workspace.all where !workspace.isVisible {
        workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).hideViaEmulation() } // todo as!
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
    let workspace = Workspace.focused
    let root = workspace.rootTilingContainer
    if root.children.count <= 3 {
        root.layout = .tiles
    } else {
        root.layout = .accordion
    }
}
