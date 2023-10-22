/// It's one of the most important function of the whole application.
/// The function is called as a feedback response on every user input
func refresh(startup: Bool = false) {
    precondition(Thread.current.isMainThread)
    //debug("refresh \(Date.now.formatted(date: .abbreviated, time: .standard))")

    // Garbage collect terminated apps and windows before working with all windows
    MacApp.garbageCollectTerminatedApps()
    // Garbage collect workspaces after apps, because workspaces contain apps.
    Workspace.garbageCollectUnusedWorkspaces()

    refreshFocusedWorkspaceBasedOnFocusedWindow()
    updateTrayText()
    detectNewWindowsAndAttachThemToWorkspaces(startup: startup)

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

private func refreshFocusedWorkspaceBasedOnFocusedWindow() {
    if focusedWorkspaceSourceOfTruth == .macOs {
        if let focusedWindow = focusedWindow {
            let focusedWorkspace: Workspace
            if focusedWindow.isFloating && !focusedWindow.isHiddenViaEmulation { // todo maybe drop once move with mouse is supported
                focusedWorkspace = mouseLocation.monitorApproximation.activeWorkspace
                focusedWindow.bindAsFloatingWindowTo(workspace: focusedWorkspace)
            } else {
                focusedWorkspace = focusedWindow.workspace
            }
            focusedWorkspace.monitor.setActiveWorkspace(focusedWorkspace)
            focusedWorkspaceName = focusedWorkspace.name
        } else {
            focusedMonitorInaccurate?.activeWorkspace.name.lets { focusedWorkspaceName = $0 }
        }
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
    for workspace in Workspace.all {
        workspace.normalizeContainers()
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

private func detectNewWindowsAndAttachThemToWorkspaces(startup: Bool) {
    for app in apps {
        let windows = app.windows // Calling .windows has side-effects
        if startup {
            for window in windows {
                window.rectBeforeAeroStart = window.getRect()
                if let workspace = window.getCenter()?.monitorApproximation.activeWorkspace {
                    window.unbindFromParent()
                    let bindingData = getBindingDataForNewWindow((window as! MacWindow).axWindow, workspace)
                    window.bindTo(parent: bindingData.parent, adaptiveWeight: bindingData.adaptiveWeight, index: bindingData.index)
                }
            }
        }
    }
}
