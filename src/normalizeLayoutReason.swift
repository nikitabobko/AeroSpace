func normalizeLayoutReason() {
    for workspace in Workspace.all {
        let windows: [Window] = workspace.allLeafWindowsRecursive
        _normalizeLayoutReason(workspace: workspace, windows: windows)
    }
    _normalizeLayoutReason(workspace: Workspace.focused, windows: macosInvisibleWindowsContainer.children.filterIsInstance(of: Window.self))
}

func _normalizeLayoutReason(workspace: Workspace, windows: [Window]) {
    for window in windows {
        let isMacosFullscreen = window.isMacosFullscreen
        let isMacosInvisible = !isMacosFullscreen && (window.isMacosMinimized || window.macAppUnsafe.nsApp.isHidden)
        switch window.layoutReason {
        case .standard:
            if isMacosFullscreen {
                window.layoutReason = .macos(prevParentKind: window.parent.kind)
                window.unbindFromParent()
                window.bind(to: workspace.macOsNativeFullscreenWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
            } else if isMacosInvisible {
                window.layoutReason = .macos(prevParentKind: window.parent.kind)
                window.unbindFromParent()
                window.bind(to: macosInvisibleWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
            }
        case .macos(let prevParentKind):
            if !isMacosFullscreen && !isMacosInvisible {
                window.layoutReason = .standard
                window.unbindFromParent()
                switch prevParentKind {
                case .workspace:
                    window.bindAsFloatingWindow(to: workspace)
                case .tilingContainer:
                    let data = getBindingDataForNewTilingWindow(workspace)
                    window.bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
                case .macosInvisibleWindowsContainer, .macosFullscreenWindowsContainer: // wtf case, should never be possible. But If encounter it, let's just re-layout window
                    let data = getBindingDataForNewWindow(window.asMacWindow().axWindow, workspace, window.macAppUnsafe)
                    window.bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
                }
            }
        }
    }
}
