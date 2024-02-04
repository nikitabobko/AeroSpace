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
    if let focusedWindow = focusedWindow {
        let focusedWorkspace: Workspace = focusedWindow.workspace
        check(focusedWorkspace.monitor.setActiveWorkspace(focusedWorkspace))
        focusedWorkspaceName = focusedWorkspace.name
    }
}

private func normalizeLayoutReason() {
    let workspace = Workspace.focused
    for window in workspace.allLeafWindowsRecursive {
        let isMacosFullscreen = window.isMacosFullscreen
        if isMacosFullscreen && !window.layoutReason.isMacos {
            window.layoutReason = .macos(prevParentKind: window.parent.kind)
            window.unbindFromParent()
            window.bindAsFloatingWindow(to: workspace)
        }
        if case .macos(let prevParentKind) = window.layoutReason, !isMacosFullscreen {
            window.layoutReason = .standard
            window.unbindFromParent()
            switch prevParentKind {
            case .workspace:
                window.bindAsFloatingWindow(to: workspace)
            case .tilingContainer:
                let data = getBindingDataForNewTilingWindow(workspace)
                window.bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
            }
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
        let _ = app.detectNewWindowsAndGetAll(startup: startup)
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
