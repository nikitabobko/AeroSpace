import AppKit

@MainActor private var focusFollowsMouseMonitor: Any? = nil
@MainActor private var focusFollowsTask: Task<(), any Error>? = nil

@MainActor func syncFocusFollowsMouse(_ config: Config) {
    if config.focusFollowsMouse.enabled == (focusFollowsMouseMonitor != nil) {
        return
    }

    if !config.focusFollowsMouse.enabled {
        NSEvent.removeMonitor(focusFollowsMouseMonitor.orDie())
        focusFollowsMouseMonitor = nil
        focusFollowsTask?.cancel()
        focusFollowsTask = nil
        return
    }

    // Interestingly, this callback seems to not fire when the mouse is down which is good,
    // because this is how I want it to work for windows/tabs/files dragging
    focusFollowsMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { @MainActor event in
        let location = event.locationInWindow.withYAxisFlipped
        focusFollowsTask?.cancel()
        focusFollowsTask = Task.startUnstructured { @MainActor in
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try checkCancellation()
            guard let windowId = await axWindowIdUnderMouse(location) else { return }
            try checkCancellation()
            let workspace = location.monitorApproximation.activeWorkspace
            guard let window = try await managedWindowUnderMouse(windowId: windowId, location: location, workspace: workspace) else { return }
            try await runLightSession(.focusFollowsMouse, token) {
                _ = window.focusWindow()
                window.nativeFocus()
            }
        }
    }
}

@MainActor
func managedWindowUnderMouse(windowId: UInt32, location: CGPoint, workspace: Workspace) async throws -> Window? {
    guard let window = Window.get(byId: windowId), window.nodeWorkspace === workspace else { return nil }

    // Preserve AeroSpace's floating-window priority when the actual window under the pointer is managed.
    // If the actual window is unmanaged, the guard above returns before this geometry fallback so transient
    // overlays such as Choosy aren't dismissed in favor of a managed window behind them.
    guard case .tilingContainer = window.windowParentCases, !window.isFullscreen else { return window }
    for child in workspace.floatingWindowsContainer.mruChildren {
        try checkCancellation()
        guard let child = child as? Window else { continue }
        guard let rect = try await child.getAxRect(.cancellable) else { continue }
        if rect.contains(location) { return child }
    }
    return window
}

@concurrent
private nonisolated func axWindowIdUnderMouse(_ location: CGPoint) async -> UInt32? {
    let systemwide = AXUIElementCreateSystemWide()
    var element: AXUIElement?
    if unsafe AXUIElementCopyElementAtPosition(systemwide, Float(location.x), Float(location.y), &element) != .success {
        return nil
    }
    guard let element else { return nil }
    let window = element.get(Ax.parentWindowRecursive)
        ?? (element.get(Ax.roleAttr) == kAXWindowRole ? element : nil)
    return window?.containingWindowId()
}
