import Foundation

/// It's one of the most important function of the whole application.
/// The function is called as a feedback response on every user input
func refresh(startSession: Bool = true, endSession: Bool = true) {
    precondition(Thread.current.isMainThread)
    debug("refresh (startSession=\(startSession), endSession=\(endSession)) \(Date.now.formatted(date: .abbreviated, time: .standard))")
    if startSession {
        NSWorkspace.activeApp = nil
        MacWindow.garbageCollectClosedWindows()
        // Garbage collect terminated apps and windows before working with all windows
        MacApp.garbageCollectTerminatedApps()
        // Garbage collect workspaces after apps, because workspaces contain apps.
        Workspace.garbageCollectUnusedWorkspaces()
    }

    refreshWorkspaces()
    detectNewWindowsAndAttachThemToWorkspaces()

    normalizeContainers()

    layoutWorkspaces()
    layoutWindows()

    if endSession {
        updateLastActiveWindow()
    }
}

func updateLastActiveWindow() {
    guard let window = NSWorkspace.activeApp?.macApp?.focusedWindow else { return }
    window.workspace.lastActiveWindow = window
}

func switchToWorkspace(_ workspace: Workspace) {
    debug("Switch to workspace: \(workspace.name)")
    refresh(endSession: false)
    if let window = workspace.lastActiveWindow ?? workspace.anyChildWindowRecursive { // switch to not empty workspace
        window.activate()
        // The switching itself will be done by refreshWorkspaces and materializeWorkspaces later in refresh
    } else { // switch to empty workspace
        precondition(workspace.isEffectivelyEmpty)
        // It's the only place in the app where I allow myself to use NSScreen.main.
        // This function isn't invoked from callbacks that's why .main should be fine
        if let focusedMonitor = NSScreen.focusedMonitorOrNilIfDesktop ?? NSScreen.main?.monitor {
            focusedMonitor.setActiveWorkspace(workspace)
        }
        defocusAllWindows()
    }
    refresh(startSession: false)
    debug("End switch to workspace: \(workspace.name)")
}

private func defocusAllWindows() {
    // Since AeroSpace doesn't show any windows, focusing AeroSpace defocuses all windows
    let current = NSRunningApplication.current
    current.activate(options: .activateIgnoringOtherApps)
    NSWorkspace.activeApp = current
}

private func refreshWorkspaces() {
    if let focusedWindow = NSWorkspace.activeApp?.macApp?.focusedWindow {
        debug("refreshWorkspaces: not empty")
        let focusedWorkspace: Workspace
        if focusedWindow.isFloating && !focusedWindow.isHiddenViaEmulation {
            focusedWorkspace = focusedWindow.getTopLeftCorner()?.monitorApproximation.getActiveWorkspace()
                    ?? focusedWindow.workspace
            focusedWindow.bindAsFloatingWindowTo(workspace: focusedWorkspace)
        } else {
            focusedWorkspace = focusedWindow.workspace
        }
        focusedWorkspace.assignedMonitorOfNotEmptyWorkspace.setActiveWorkspace(focusedWorkspace)
        ViewModel.shared.focusedWorkspaceTrayText = focusedWorkspace.name
    } else {
        debug("refreshWorkspaces: empty")
        ViewModel.shared.focusedWorkspaceTrayText = currentEmptyWorkspace.name
    }
}

private func layoutWorkspaces() {
    for workspace in Workspace.all {
        debug("materializeWorkspaces: \(workspace.name) visible=\(workspace.isVisible)")
        if workspace.isVisible {
            workspace.allWindowsRecursive.forEach { $0.unhideViaEmulation() }
        } else {
            workspace.allWindowsRecursive.forEach { $0.hideViaEmulation() }
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
