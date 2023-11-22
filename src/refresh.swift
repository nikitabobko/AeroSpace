/// It's one of the most important function of the whole application.
/// The function is called as a feedback response on every user input.
/// The function is idempotent.
func refresh(startup: Bool = false, layout: Bool = true) {
    check(Thread.current.isMainThread)
    //debug("refresh \(Date.now.formatted(date: .abbreviated, time: .standard))")

    // Garbage collect terminated apps and windows before working with all windows
    MacApp.garbageCollectTerminatedApps()
    // Garbage collect workspaces after apps, because workspaces contain apps.
    Workspace.garbageCollectUnusedWorkspaces()

    if !TrayMenuModel.shared.isEnabled {
        return
    }

    takeFocusFromMacOs(startup: startup)
    refreshFocusedWorkspaceBasedOnFocusedWindow()
    updateTrayText()
    detectNewWindowsAndAttachThemToWorkspaces(startup: startup)

    normalizeContainers()

    if layout {
        layoutWorkspaces()
        layoutWindows()
        syncFocusToMacOs(startup: startup)
    }
}

func refreshObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    refresh()
}

func syncFocusToMacOs(startup: Bool) {
    let native = getNativeFocusedWindow(startup: startup)
    // native could be some popup (e.g. recent files in IntelliJ IDEA). Don't steal focus in that case
    if native != nil && native != focusedWindow {
        focusedWindow?.nativeFocus()
    }
}

func takeFocusFromMacOs(startup: Bool) {
    if let window = getNativeFocusedWindow(startup: startup), getFocusSourceOfTruth(startup: startup) == .macOs {
        window.focus()
        setFocusSourceOfTruth(.ownModel, startup: startup)
    }
}

private func refreshFocusedWorkspaceBasedOnFocusedWindow() {
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
