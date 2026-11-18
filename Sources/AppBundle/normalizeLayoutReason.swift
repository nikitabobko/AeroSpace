@MainActor func normalizeLayoutReason() async throws {
    for workspace in Workspace.all {
        let windows: [Window] = workspace.allLeafWindowsRecursive
        try await _normalizeLayoutReason(workspace: workspace, windows: windows)
    }
    try await _normalizeLayoutReason(workspace: globalFocus.workspace, windows: macosMinimizedWindowsContainer.children.filterIsInstance(of: Window.self))
    try await validateStillPopups()
}

@MainActor private func validateStillPopups() async throws {
    for node in macosPopupWindowsContainer.children {
        try await (node as! MacWindow).relayoutIfNoLongerPopup()
    }
}

extension MacWindow {
    /// Some windows are mistakenly detected as popups right after they are created
    /// (their AX attributes aren't fully initialized yet). Re-check and relayout them as regular windows
    @MainActor func relayoutIfNoLongerPopup() async throws {
        guard parent is MacosPopupWindowsContainer else { return }
        let windowLevel = try await getWindowLevel(.cancellable)
        if try await isWindowHeuristic(windowLevel, .cancellable) {
            try await relayoutWindow(on: globalFocus.workspace, .cancellable)
            await runOnWindowDetected(ifConventional: self)
        }
    }
}

@MainActor private func _normalizeLayoutReason(workspace: Workspace, windows: [Window]) async throws {
    let states = try await windows.mapConcurrently { try await $0.getMacosWindowNativeState(.cancellable) }
    for (window, state) in zip(windows, states) {
        let isMacosFullscreen = state == .nativeFullscreen
        let isMacosMinimized = state == .nativeMinimized
        let isMacosWindowOfHiddenApp = !isMacosFullscreen && !isMacosMinimized &&
            !config.automaticallyUnhideMacosHiddenApps && window.macAppUnsafe.nsApp.isHidden
        switch window.layoutReason {
            case .standard:
                guard let parent = window.windowParentCases else { continue }
                switch true {
                    case isMacosFullscreen:
                        window.layoutReason = .macos(prevParentKind: parent.kind)
                        window.bind(to: workspace.macOsNativeFullscreenWindowsContainer, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)
                    case isMacosMinimized:
                        window.layoutReason = .macos(prevParentKind: parent.kind)
                        window.bind(to: macosMinimizedWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
                    case isMacosWindowOfHiddenApp:
                        window.layoutReason = .macos(prevParentKind: parent.kind)
                        window.bind(to: workspace.macOsNativeHiddenAppsWindowsContainer, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)
                    default: break
                }
            case .macos(let prevParentKind):
                if !isMacosFullscreen && !isMacosMinimized && !isMacosWindowOfHiddenApp {
                    try await exitMacOsNativeUnconventionalState(window: window, prevParentKind: prevParentKind, workspace: workspace, .cancellable)
                }
        }
    }
}

@MainActor func exitMacOsNativeUnconventionalState(
    window: Window,
    prevParentKind: WindowParentCases.Kind,
    workspace: Workspace,
    _ cm: CancellationMode,
) async throws {
    window.layoutReason = .standard
    switch prevParentKind {
        case .floatingWindowsContainer:
            window.bindAsFloatingWindow(to: workspace)
        case .tilingContainer:
            try await window.relayoutWindow(on: workspace, cm, forceTile: true)
        case .macosPopupWindowsContainer: // Since the window was minimized/fullscreened it was mistakenly detected as popup. Relayout the window
            try await window.relayoutWindow(on: workspace, cm)
        case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer: // wtf case, should never be possible. But If encounter it, let's just re-layout window
            try await window.relayoutWindow(on: workspace, cm)
    }
}
