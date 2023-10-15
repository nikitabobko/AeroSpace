/// It's one of the most important function of the whole application.
/// The function is called as a feedback response on every user input
func refresh(startup: Bool = false) {
    precondition(Thread.current.isMainThread)
    //debug("refresh \(Date.now.formatted(date: .abbreviated, time: .standard))")

    // Garbage collect terminated apps and windows before working with all windows
    MacApp.garbageCollectTerminatedApps()
    // Garbage collect workspaces after apps, because workspaces contain apps.
    Workspace.garbageCollectUnusedWorkspaces()

    refreshWorkspaces()
    detectNewWindowsAndAttachThemToWorkspaces()

    normalizeContainers()

    layoutWorkspaces()
    layoutWindows(startup: startup)

    updateMostRecentWindow()
}

func refreshObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    refresh()
}

func updateMostRecentWindow() {
    focusedWindow?.markAsMostRecentChild()
    if focusedWindow?.workspace.mostRecentWindowForAccordion == focusedWindow {
        focusedWindow?.workspace.resetMruForAccordionRecursive()
    }
}

private func refreshWorkspaces() {
    if let focusedWindow = focusedWindow as! MacWindow? { // todo as!
        //debug("refreshWorkspaces: not empty")
        let focusedWorkspace: Workspace
        if focusedWindow.isFloating && !focusedWindow.isHiddenViaEmulation { // todo maybe drop once move with mouse is supported
            focusedWorkspace = focusedWindow.getCenter()?.monitorApproximation.activeWorkspace
                    ?? focusedWindow.workspace
            focusedWindow.bindAsFloatingWindowTo(workspace: focusedWorkspace)
        } else {
            focusedWorkspace = focusedWindow.workspace
        }
        focusedWorkspace.monitor.setActiveWorkspace(focusedWorkspace)
        focusedWorkspaceName = focusedWorkspace.name
    }
    updateTrayText()
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
    for workspace in Workspace.all {
        workspace.rootTilingContainer.normalizeContainersRecursive()
    }
}

private func layoutWindows(startup: Bool) {
    for monitor in monitors {
        let workspace = monitor.activeWorkspace
        if workspace.isEffectivelyEmpty { continue }
        let rect = monitor.visibleRect
        workspace.layoutRecursive(rect.topLeftCorner, width: rect.width, height: rect.height, startup: startup)
    }
}

private func detectNewWindowsAndAttachThemToWorkspaces() {
    for app in apps {
        let _ = app.windows
    }
}
