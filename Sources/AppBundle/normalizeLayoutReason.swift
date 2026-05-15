import CoreGraphics

@MainActor
func normalizeLayoutReason() async throws {
    for workspace in Workspace.all {
        let windows: [Window] = workspace.allLeafWindowsRecursive
        try await _normalizeLayoutReason(workspace: workspace, windows: windows)
    }
    try await _normalizeLayoutReason(workspace: focus.workspace, windows: macosMinimizedWindowsContainer.children.filterIsInstance(of: Window.self))
    try await validateStillPopups()
}

@MainActor
private func validateStillPopups() async throws {
    for node in macosPopupWindowsContainer.children {
        let popup = (node as! MacWindow)
        let windowLevel = getWindowLevel(for: popup.windowId)
        if try await popup.isWindowHeuristic(windowLevel) {
            try await popup.relayoutWindow(on: focus.workspace)
            try await tryOnWindowDetected(popup)
        }
    }
}

@MainActor
private func _normalizeLayoutReason(workspace: Workspace, windows: [Window]) async throws {
    for window in windows {
        let isMacosFullscreen = try await window.isMacosFullscreen
        let isMacosMinimized = try await (!isMacosFullscreen).andAsync { @MainActor @Sendable in try await window.isMacosMinimized }
        let isMacosWindowOfHiddenApp = !isMacosFullscreen && !isMacosMinimized &&
            !config.automaticallyUnhideMacosHiddenApps && window.macAppUnsafe.nsApp.isHidden
        switch window.layoutReason {
            case .standard:
                guard window.parent != nil else { continue }
                switch true {
                    case isMacosFullscreen:
                        enterMacOsUnconventionalState(window: window, newParent: workspace.macOsNativeFullscreenWindowsContainer, newWeight: WEIGHT_DOESNT_MATTER)
                    case isMacosMinimized:
                        enterMacOsUnconventionalState(window: window, newParent: macosMinimizedWindowsContainer, newWeight: 1)
                    case isMacosWindowOfHiddenApp:
                        enterMacOsUnconventionalState(window: window, newParent: workspace.macOsNativeHiddenAppsWindowsContainer, newWeight: WEIGHT_DOESNT_MATTER)
                    default: break
                }
            case .macos(let prev):
                if !isMacosFullscreen && !isMacosMinimized && !isMacosWindowOfHiddenApp {
                    try await exitMacOsNativeUnconventionalState(window: window, prev: prev, workspace: workspace)
                }
        }
    }
}

@MainActor
private func enterMacOsUnconventionalState(window: Window, newParent: NonLeafTreeNodeObject, newWeight: CGFloat) {
    guard let oldParent = window.parent, let oldIndex = window.ownIndex else { return }
    let oldWeight: CGFloat = (oldParent as? TilingContainer)
        .map { window.getWeight($0.orientation) } ?? WEIGHT_DOESNT_MATTER
    window.layoutReason = .macos(prev: MacosPrev(parent: oldParent, index: oldIndex, adaptiveWeight: oldWeight))
    window.bind(to: newParent, adaptiveWeight: newWeight, index: INDEX_BIND_LAST)
    // The layout just changed: any cached "world" from earlier (which would mark
    // this window as still-tiled) is now stale and would re-tile this window if
    // restoration fires for unrelated reasons (e.g. transient browser popup gets
    // gc'd and re-registered).
    resetClosedWindowsCache()
}

@MainActor
func exitMacOsNativeUnconventionalState(window: Window, prev: MacosPrev, workspace: Workspace) async throws {
    window.layoutReason = .standard

    // Preferred path: restore to the exact container the window came from, at the
    // same slot. This preserves nested splits the user set up before fullscreen.
    if let prevParent = prev.parent, prevParent.nodeWorkspace === workspace {
        window.unbindFromParent()
        // Sibling anchors are more robust than the raw saved index because the
        // parent's children list may have shifted while the window was in the
        // unconventional container (e.g., another sibling briefly gc'd and
        // re-registered, or another sibling also entered and exited fullscreen).
        let restoreIndex = prev.resolveIndex(in: prevParent)
        // Use WEIGHT_AUTO so the window picks up the current average sibling weight.
        // Saving prev.adaptiveWeight is wrong because while this window was in the
        // unconventional container, its siblings' weights were rebalanced to fill
        // the freed space; restoring the old absolute weight makes this window
        // noticeably smaller than its siblings after the rebalance.
        window.bind(to: prevParent, adaptiveWeight: WEIGHT_AUTO, index: restoreIndex)
        // Same reason as in enterMacOsUnconventionalState: the cached world from when
        // this window was still in the unconventional container is now stale and
        // would re-float this window if restoration fires.
        resetClosedWindowsCache()
        return
    }
    resetClosedWindowsCache()

    // Fallback: previous parent was gc'd (e.g. flattened away while the window
    // was fullscreen) or moved to another workspace. Use the previous kind to
    // pick a reasonable destination.
    switch prev.parentKind {
        case .workspace:
            window.bindAsFloatingWindow(to: workspace)
        case .tilingContainer:
            try await window.relayoutWindow(on: workspace, forceTile: true)
        case .macosPopupWindowsContainer: // Since the window was minimized/fullscreened it was mistakenly detected as popup. Relayout the window
            try await window.relayoutWindow(on: workspace)
        case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer: // wtf case, should never be possible. But If encounter it, let's just re-layout window
            try await window.relayoutWindow(on: workspace)
    }
}
