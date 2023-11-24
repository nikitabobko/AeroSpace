/// It's one of the most important function of the whole application.
/// The function is called as a feedback response on every user input.
/// The function is idempotent.
func refreshSession(startup: Bool = false, body: () -> Void) {
    check(Thread.current.isMainThread)
    gc()

    if !TrayMenuModel.shared.isEnabled {
        return
    }

    takeFocusFromMacOs(startup: startup)
    let focusBefore = focusedWindow

    refreshModel(startup: startup)
    body()
    refreshModel(startup: startup)

    let focusAfter = focusedWindow

    updateTrayText()
    layoutWorkspaces()
    layoutWindows()
    syncFocusToMacOs(startup: startup, force: focusBefore != focusAfter)
}

func refreshAndLayout(startup: Bool = false) {
    refreshSession(startup: startup, body: {})
}

func refreshModel(startup: Bool) {
    gc()
    refreshFocusedWorkspaceBasedOnFocusedWindow()
    // todo not sure that it should be part of the refreshModel
    //  now it's a part of refreshModel mainly because of await enable-and-wait
    detectNewWindowsAndAttachThemToWorkspaces(startup: startup)
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

func syncFocusToMacOs(startup: Bool, force: Bool) {
    let native = getNativeFocusedWindow(startup: startup)
    if force /*for example `focus right` when "recent files" is focused in IDEA*/ ||
           // native would be nil if it's a popup (e.g. recent files in IntelliJ IDEA). Don't steal focus in that case
           native != nil && native != focusedWindow {
        focusedWindow?.nativeFocus()
    }
}

func takeFocusFromMacOs(startup: Bool) {
    if let window = getNativeFocusedWindow(startup: startup), getFocusSourceOfTruth(startup: startup) == .macOs {
        window.focus()
        setFocusSourceOfTruth(.ownModel, startup: startup)
    }
}

private func refreshFocusedWorkspaceBasedOnFocusedWindow() { // todo drop. It should no longer be necessary
    if let focusedWindow = focusedWindow {
        let focusedWorkspace: Workspace = focusedWindow.workspace
        check(focusedWorkspace.monitor.setActiveWorkspace(focusedWorkspace))
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
}

private func normalizeContainers() {
    for workspace in Workspace.all { // todo do it only for visible workspaces?
        workspace.normalizeContainers()
    }
}

private func layoutWindows() {
    let focusedWindow = focusedWindow
    for monitor in monitors {
        let workspace = monitor.activeWorkspace
        if workspace.isEffectivelyEmpty { continue }
        let rect = monitor.visibleRect
        workspace.layoutRecursive(rect.topLeftCorner, focusedWindow: focusedWindow, width: rect.width, height: rect.height)
    }
}

private func detectNewWindowsAndAttachThemToWorkspaces(startup: Bool) {
    if startup { // todo move to MacWindow.get
        //putWindowsOnWorkspacesOfTheirMonitors()
        putWindowsAtStartup()
    } else {
        for app in apps {
            let _ = app.windows(startup: startup) // Calling .windows has side-effects
        }
    }
}

private func putWindowsAtStartup() {
    switch config.nonEmptyWorkspacesRootContainersLayoutOnStartup {
    case .tiles:
        for workspace in Workspace.all.filter { !$0.isEffectivelyEmpty } {
            workspace.rootTilingContainer.layout = .tiles
        }
    case .accordion:
        for workspace in Workspace.all.filter { !$0.isEffectivelyEmpty } {
            workspace.rootTilingContainer.layout = .accordion
        }
    case .smart:
        for workspace in Workspace.all.filter { !$0.isEffectivelyEmpty } {
            let root = workspace.rootTilingContainer
            if root.children.count <= 3 {
                root.layout = .tiles
            } else {
                root.layout = .accordion
            }
        }
    }
}
