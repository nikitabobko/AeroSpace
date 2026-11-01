import AppKit
import Common

@MainActor
private var activeRefreshTask: Task<(), any Error>? = nil

@MainActor
func scheduleCancellableCompleteRefreshSession(
    _ event: RefreshSessionEvent,
    optimisticallyPreLayoutWorkspaces: Bool = false,
) {
    activeRefreshTask?.cancel()
    activeRefreshTask = Task.startUnstructured { @MainActor in
        try checkCancellation()
        await runHeavyCompleteRefreshSession(
            event,
            assumeCancellable: true,
            optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces,
        )
    }
}

@MainActor
func runHeavyCompleteRefreshSession(
    _ event: RefreshSessionEvent,
    assumeCancellable: Bool,
    layoutWorkspaces shouldLayoutWorkspaces: Bool = true,
    optimisticallyPreLayoutWorkspaces: Bool = false,
) async {
    let state = signposter.beginInterval(#function, "event: \(event) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
    defer { signposter.endInterval(#function, state) }
    if !TrayMenuModel.shared.isEnabled {
        TabHeadersPanelController.shared.closeAll()
        return
    }
    let res = await Result {
        try await $refreshSessionEvent.withValue(event) {
            let nativeFocused = try await getNativeFocusedWindow(.cancellable)
            if let nativeFocused { try await debugWindowsIfRecording(nativeFocused, .cancellable) }
            updateFocusCache(nativeFocused)

            if shouldLayoutWorkspaces && optimisticallyPreLayoutWorkspaces { try await layoutWorkspaces() }

            await refreshModel_nonCancellable()
            try await refresh()
            gcMonitors()

            updateTrayText()
            SecureInputPanel.shared.refresh()
            try await normalizeLayoutReason()
            if shouldLayoutWorkspaces { try await layoutWorkspaces() }
        }
    }
    switch res {
        case .success(()): break
        case .failure(let err as CancellationError): check(assumeCancellable, "Non cancellable refresh session was canceled: \(err) (\(type(of: err)))")
        case .failure(let err): die("Illegal error: \(err)")
    }
}

@MainActor
func runLightSession<T>(
    _ event: RefreshSessionEvent,
    _: RunSessionGuard,
    body: @MainActor () async throws -> T,
) async throws -> T {
    let state = signposter.beginInterval(#function, "event: \(event) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
    defer { signposter.endInterval(#function, state) }
    activeRefreshTask?.cancel() // Give priority to runSession
    activeRefreshTask = nil
    return try await $refreshSessionEvent.withValue(event) {
        let nativeFocused = try await getNativeFocusedWindow(.cancellable)
        if let nativeFocused { try await debugWindowsIfRecording(nativeFocused, .cancellable) }
        updateFocusCache(nativeFocused)
        let focusBefore = globalFocus.windowOrNil

        await refreshModel_nonCancellable()
        let result = try await body()
        await refreshModel_nonCancellable()

        let focusAfter = globalFocus.windowOrNil

        updateTrayText()
        SecureInputPanel.shared.refresh()
        if !event.isFocusFollowsMouse { try await layoutWorkspaces() }
        if focusBefore != focusAfter {
            focusAfter?.nativeFocus() // syncFocusToMacOs
        }
        if !event.isFocusFollowsMouse { scheduleCancellableCompleteRefreshSession(event) }
        return result
    }
}

enum RunSessionGuard: Sendable {
    case forceRun

    @MainActor
    static var isServerEnabled: Self? { TrayMenuModel.shared.isEnabled ? forceRun : nil }
    @MainActor
    static func isServerEnabled(orIsEnableCommand command: (any Command)?) -> Self? {
        command is EnableCommand ? .forceRun : .isServerEnabled
    }
    @MainActor
    static func checkServerIsEnabledOrDie(fileId: MyFileId = #myFileId) -> Self {
        .isServerEnabled ?? dieT("server is disabled", fileId: fileId)
    }
}

@MainActor
func refreshModel_nonCancellable() async {
    if refreshSessionEvent?.isFocusFollowsMouse == true {
        await checkOnFocusChangedCallbacks_nonCancellable()
    } else {
        Workspace.garbageCollectUnusedWorkspaces()
        Workspace.forceAssignWorkspaces()
        await checkOnFocusChangedCallbacks_nonCancellable()
        normalizeContainers()
    }
}

@MainActor
private func refresh() async throws {
    // Garbage collect terminated apps and windows before working with all windows
    let mapping = try await MacApp
        .refreshAllAndGetAliveWindowIds(frontmostAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    let aliveWindowIds = mapping.values.flatMap(\.keys).toSet()

    for window in MacWindow.allWindows {
        if !aliveWindowIds.contains(window.windowId) {
            window.lifeStatus = .dead
            window.garbageCollect(skipClosedWindowsCache: false)
        }
    }
    for (app, windows) in mapping {
        for (windowId, lifeStatus) in windows {
            try await MacWindow.getOrRegister(windowId: windowId, macApp: app).lifeStatus = lifeStatus
        }
    }

    // Garbage collect workspaces after apps, because workspaces contain apps.
    Workspace.garbageCollectUnusedWorkspaces()
}

func refreshObs(_: AXObserver, _: AXUIElement, notif: CFString, _: UnsafeMutableRawPointer?) {
    let notif = notif as String
    Task.startUnstructured { @MainActor in
        if !TrayMenuModel.shared.isEnabled { return }
        scheduleCancellableCompleteRefreshSession(.ax(notif))
    }
}

enum OptimalHideCorner {
    case bottomLeftCorner, bottomRightCorner
}

@MainActor
private func layoutWorkspaces() async throws {
    if !TrayMenuModel.shared.isEnabled {
        TabHeadersPanelController.shared.closeAll()
        for workspace in Workspace.all {
            workspace.allLeafWindowsRecursive.forEach { $0.unhideFromCorner() }
            _ = try await workspace.layoutWorkspace() // Unhide tiling windows from corner
        }
        return
    }
    let monitors = globalUnsortedMonitorInfos
    var tabHeaderSnapshots: [TabHeaderSnapshot] = []
    // to reduce flicker, first unhide visible workspaces, then hide invisible ones
    for monitor in monitors {
        let workspace = monitor.visibleWorkspace
        tabHeaderSnapshots += try await workspace.layoutWorkspace()
    }
    for workspace in Workspace.all where !workspace.isVisible {
        let corner = workspace.workspaceMonitorInfo.optimalHideCorner(monitors: monitors)
        for window in workspace.allLeafWindowsRecursive {
            try await window.hideInCorner(corner)
        }
    }
    TabHeadersPanelController.shared.refresh(with: tabHeaderSnapshots)
}

@MainActor
private func normalizeContainers() {
    // Can't do it only for visible workspace because most of the commands support --window-id and --workspace flags
    for workspace in Workspace.all {
        workspace.normalizeContainers()
    }
}
