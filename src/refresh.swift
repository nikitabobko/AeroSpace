/// It's one of the most important function of the whole application.
/// The function is called as a feedback response on every user input
func refresh(startSession: Bool = true) {
    precondition(Thread.current.isMainThread)
    debug("refresh (startSession=\(startSession)) \(Date.now.formatted(date: .abbreviated, time: .standard))")
    if startSession {
        setFocusedAppForCurrentRefreshSession(app: nil)
    }

    MacWindow.garbageCollectClosedWindows()
    // Garbage collect terminated apps and windows before working with all windows
    MacApp.garbageCollectTerminatedApps()
    // Garbage collect workspaces after apps, because workspaces contain apps.
    Workspace.garbageCollectUnusedWorkspaces()

    refreshWorkspaces()
    detectNewWindowsAndAttachThemToWorkspaces()

    normalizeContainers()

    layoutWorkspaces()
    layoutWindows()

    updateLastActiveWindow()
}

func refreshObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    refresh()
}

func updateLastActiveWindow() {
    guard let window = focusedWindow else { return }
    window.workspace.mruWindows.pushOrRaise(window)
}

private func refreshWorkspaces() {
    if let focusedWindow = focusedWindow {
        debug("refreshWorkspaces: not empty")
        let focusedWorkspace: Workspace
        if focusedWindow.isFloating && !focusedWindow.isHiddenViaEmulation {
            focusedWorkspace = focusedWindow.getCenter()?.monitorApproximation.getActiveWorkspace()
                    ?? focusedWindow.workspace
            focusedWindow.bindAsFloatingWindowTo(workspace: focusedWorkspace)
        } else {
            focusedWorkspace = focusedWindow.workspace
        }
        focusedWorkspace.assignedMonitorOfNotEmptyWorkspace.setActiveWorkspace(focusedWorkspace)
        TrayMenuModel.shared.focusedWorkspaceTrayText = focusedWorkspace.name
    } else {
        debug("refreshWorkspaces: empty")
        TrayMenuModel.shared.focusedWorkspaceTrayText = currentEmptyWorkspace.name
    }
}

private func layoutWorkspaces() {
    for workspace in Workspace.all {
        debug("layoutWorkspaces: \(workspace.name) visible=\(workspace.isVisible)")
        if workspace.isVisible {
            workspace.allLeafWindowsRecursive.forEach { $0.unhideViaEmulation() }
        } else {
            workspace.allLeafWindowsRecursive.forEach { $0.hideViaEmulation() }
        }
    }
}

private func normalizeContainers() {
    for workspace in Workspace.all {
        workspace.rootTilingContainer.normalizeContainersRecursive()
    }
}

private func layoutWindows() {
    for screen in NSScreen.screens {
        let workspace = screen.monitor.getActiveWorkspace()
        if workspace.isEffectivelyEmpty { continue }
        let rect = screen.visibleRect
        workspace.rootTilingContainer.normalizeWeightsRecursive()
        workspace.layoutRecursive(rect.topLeftCorner, width: rect.width, height: rect.height)
    }
}

private func detectNewWindowsAndAttachThemToWorkspaces() {
    for app in NSWorkspace.shared.runningApplications {
        if app.activationPolicy == .regular {
            let _ = app.macApp?.windows
        }
    }
}
