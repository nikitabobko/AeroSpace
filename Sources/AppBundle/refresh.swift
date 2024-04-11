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
    takeFocusFromMacOs(nativeFocused, startup: startup)
    let focusBefore = focusedWindow

    refreshModel()
    let result = body()
    refreshModel()

    let focusAfter = focusedWindow

    if startup {
        smartLayoutAtStartup()
    }

    if TrayMenuModel.shared.isEnabled {
        if forceFocus || focusBefore != focusAfter {
            focusedWindow?.nativeFocus() // syncFocusToMacOs
        }

        updateTrayText()
        normalizeLayoutReason()
        layoutWorkspaces()
    }
    return result
}

func refreshAndLayout(startup: Bool = false) {
    refreshSession(startup: startup, body: {})
}

func refreshModel() {
    gc()
    refreshFocusedWorkspaceBasedOnFocusedWindow()
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

func takeFocusFromMacOs(_ nativeFocused: Window?, startup: Bool) { // alternative name: syncFocusFromMacOs
    if let nativeFocused, getFocusSourceOfTruth(startup: startup) == .macOs {
        nativeFocused.focus()
        setFocusSourceOfTruth(.ownModel, startup: startup)
    }
}

private func refreshFocusedWorkspaceBasedOnFocusedWindow() { // todo drop. It should no longer be necessary
    if let focusedWindow = focusedWindow, let monitor = focusedWindow.nodeMonitor {
        // todo it's rather refresh focused monitor
        let focusedWorkspace: Workspace = monitor.activeWorkspace
        check(focusedWorkspace.workspaceMonitor.setActiveWorkspace(focusedWorkspace))
        focusedWorkspaceName = focusedWorkspace.name
    }
}

private func layoutWorkspaces() {
    for workspace in Workspace.all {
        if workspace.isVisible {
            // todo no need to unhide tiling windows (except for keeping hide/unhide state variables invariants)
            workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideViaEmulation() } // todo as!
        } else {
            workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).hideViaEmulation() } // todo as!
        }
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
