func normalizeLayoutReason(startup: Bool) {
    for workspace in Workspace.all {
        let windows: [Window] = workspace.allLeafWindowsRecursive
        _normalizeLayoutReason(workspace: workspace, windows: windows)
    }
    _normalizeLayoutReason(workspace: focus.workspace, windows: macosMinimizedWindowsContainer.children.filterIsInstance(of: Window.self))
    validateStillPopups(startup: startup)
}

private func validateStillPopups(startup: Bool) {
    for node in macosPopupWindowsContainer.children {
        let popup = (node as! MacWindow)
        if isWindow(popup.axWindow, popup.macApp) {
            popup.relayoutWindow(on: focus.workspace)
            tryOnWindowDetected(popup, startup: startup)
        }
    }
}

private func _normalizeLayoutReason(workspace: Workspace, windows: [Window]) {
    for window in windows {
        let isMacosFullscreen = window.isMacosFullscreen
        let isMacosInvisible = !isMacosFullscreen &&
            (window.isMacosMinimized || !config.automaticallyUnhideMacosHiddenApps && window.macAppUnsafe.nsApp.isHidden)
        switch window.layoutReason {
            case .standard:
                if isMacosFullscreen {
                    window.layoutReason = .macos(prevParentKind: window.parent.kind)
                    window.bind(to: workspace.macOsNativeFullscreenWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
                } else if isMacosInvisible {
                    window.layoutReason = .macos(prevParentKind: window.parent.kind)
                    window.bind(to: macosMinimizedWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
                }
            case .macos(let prevParentKind):
                if !isMacosFullscreen && !isMacosInvisible {
                    exitMacOsNativeOrInvisibleState(window: window, prevParentKind: prevParentKind, workspace: workspace)
                }
        }
    }
}

func exitMacOsNativeOrInvisibleState(window: Window, prevParentKind: NonLeafTreeNodeKind, workspace: Workspace) {
    window.layoutReason = .standard
    switch prevParentKind {
        case .workspace:
            window.bindAsFloatingWindow(to: workspace)
        case .tilingContainer:
            window.relayoutWindow(on: workspace, forceTile: true)
        case .macosPopupWindowsContainer: // Since the window was minimized/fullscreened it was mistakenly detected as popup. Relayout the window
            window.relayoutWindow(on: workspace)
        case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer: // wtf case, should never be possible. But If encounter it, let's just re-layout window
            window.relayoutWindow(on: workspace)
    }
}
