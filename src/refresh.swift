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

    refreshFocusedWorkspaceBasedOnFocusedWindow()
    updateTrayText()
    detectNewWindowsAndAttachThemToWorkspaces(startup: startup)

    normalizeContainers()

    if layout {
        layoutWorkspaces()
        layoutWindows()
    }

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
    if focusedWorkspaceSourceOfTruth == .macOs, let focusedWindow = focusedWindow {
        let focusedWorkspace: Workspace = focusedWindow.workspace
        focusedWorkspace.monitor.setActiveWorkspace(focusedWorkspace)
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
    if startup {
        putWindowsOnWorkspacesOfTheirMonitors()
        putWindowsInDecks()
    } else {
        for app in apps {
            let _ = app.windows // Calling .windows has side-effects
        }
    }
}

private func putWindowsInDecks() {
    let windowGroups: [Workspace: [Window]] =
        apps.flatMap(\.windows).filter { !$0.isFloating }.grouped(by: \.workspace)
    for (workspace, windows) in windowGroups {
        let root = workspace.rootTilingContainer
        switch root.layout {
        case .list:
            var deckIndex = 0
            let decks = [
                TilingContainer(parent: root, adaptiveWeight: 1, root.orientation.opposite, .accordion, index: INDEX_BIND_LAST),
                TilingContainer(parent: root, adaptiveWeight: 1, root.orientation.opposite, .accordion, index: INDEX_BIND_LAST),
            ]
            for window in windows.reversed() {
                window.unbindFromParent()
                window.bind(to: decks[deckIndex], adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
                deckIndex = (deckIndex + 1) % decks.count
            }
        case .accordion:
            break
        }
    }
}

private func putWindowsOnWorkspacesOfTheirMonitors() {
    for app in apps {
        for window in app.windows {
            if let workspace = window.getCenter()?.monitorApproximation.activeWorkspace {
                switch window.unbindFromParent().parent.kind {
                case .workspace:
                    window.bind(to: workspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
                case .tilingContainer:
                    window.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
                }
            }
        }
    }
}
