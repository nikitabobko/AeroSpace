import AppKit
import Common

@MainActor
var activeRefreshTask: Task<(), any Error>? = nil // Made internal for RefreshDebouncer access

@MainActor
let refreshDebouncer = RefreshDebouncer()

@MainActor
func runRefreshSessionDebounced(
    _ event: RefreshSessionEvent,
    screenIsDefinitelyUnlocked: Bool,
    optimisticallyPreLayoutWorkspaces: Bool = false
) {
    refreshDebouncer.debounce(
        event: event,
        screenIsDefinitelyUnlocked: screenIsDefinitelyUnlocked,
        optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces
    )
}

@MainActor
func runRefreshSession(
    _ event: RefreshSessionEvent,
    screenIsDefinitelyUnlocked: Bool, // todo rename
    optimisticallyPreLayoutWorkspaces: Bool = false,
    debounce: Bool = true // New parameter to control debouncing
) {
    if debounce {
        // Use debounced refresh for most cases
        runRefreshSessionDebounced(event, screenIsDefinitelyUnlocked: screenIsDefinitelyUnlocked, optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces)
    } else {
        // Immediate refresh for critical operations
        if screenIsDefinitelyUnlocked { resetClosedWindowsCache() }
        activeRefreshTask?.cancel()
        activeRefreshTask = Task { @MainActor in
            try checkCancellation()
            try await runRefreshSessionBlocking(event, optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces)
        }
    }
}

@MainActor
func runRefreshSessionBlocking(
    _ event: RefreshSessionEvent,
    layoutWorkspaces shouldLayoutWorkspaces: Bool = true,
    optimisticallyPreLayoutWorkspaces: Bool = false,
) async throws {
    let state = signposter.beginInterval(#function, "event: \(event) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
    defer { signposter.endInterval(#function, state) }
    if !TrayMenuModel.shared.isEnabled { return }
    try await $refreshSessionEvent.withValue(event) {
        try await $_isStartup.withValue(event.isStartup) {
            let nativeFocused = try await getNativeFocusedWindow()
            if let nativeFocused { try await debugWindowsIfRecording(nativeFocused) }
            updateFocusCache(nativeFocused)

            if shouldLayoutWorkspaces && optimisticallyPreLayoutWorkspaces { try await layoutWorkspaces() }

            refreshModel()
            try await refresh()
            gcMonitors()

            updateTrayText()
            try await normalizeLayoutReason()
            if shouldLayoutWorkspaces { try await layoutWorkspaces() }
        }
    }
}

@MainActor
func runSession<T>(
    _ event: RefreshSessionEvent,
    _ token: RunSessionGuard,
    body: @MainActor () async throws -> T
) async throws -> T {
    let state = signposter.beginInterval(#function, "event: \(event) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
    defer { signposter.endInterval(#function, state) }
    activeRefreshTask?.cancel() // Give priority to runSession
    activeRefreshTask = nil
    return try await $refreshSessionEvent.withValue(event) {
        try await $_isStartup.withValue(event.isStartup) {
            resetClosedWindowsCache()

            let nativeFocused = try await getNativeFocusedWindow()
            if let nativeFocused { try await debugWindowsIfRecording(nativeFocused) }
            updateFocusCache(nativeFocused)
            let focusBefore = focus.windowOrNil

            refreshModel()
            let result = try await body()
            refreshModel()

            let focusAfter = focus.windowOrNil

            updateTrayText()
            try await layoutWorkspaces()
            if focusBefore != focusAfter {
                focusAfter?.nativeFocus() // syncFocusToMacOs
            }
            runRefreshSession(event, screenIsDefinitelyUnlocked: false, debounce: false) // Don't debounce within critical sessions
            return result
        }
    }
}

struct RunSessionGuard: Sendable {
    @MainActor
    static var isServerEnabled: RunSessionGuard? { TrayMenuModel.shared.isEnabled ? forceRun : nil }
    @MainActor
    static func isServerEnabled(orIsEnableCommand command: (any Command)?) -> RunSessionGuard? {
        command is EnableCommand ? .forceRun : .isServerEnabled
    }
    @MainActor
    static var checkServerIsEnabledOrDie: RunSessionGuard { .isServerEnabled ?? dieT("server is disabled") }
    static let forceRun = RunSessionGuard()
    private init() {}
}

@MainActor
func refreshModel() {
    Workspace.garbageCollectUnusedWorkspaces()
    checkOnFocusChangedCallbacks()
    normalizeContainers()
}

@MainActor
private func refresh() async throws {
    // Check if we can do an incremental update
    if WindowChangeTracker.shared.hasPendingChanges() {
        try await refreshIncremental()
    } else {
        try await refreshFull()
    }
}

@MainActor
private func refreshIncremental() async throws {
    let pendingChanges = WindowChangeTracker.shared.getPendingChanges()
    
    // Process destroyed windows first
    for (windowId, changes) in pendingChanges where changes.contains(.destroyed) {
        if let window = MacWindow.allWindowsMap[windowId] {
            window.garbageCollect(skipClosedWindowsCache: false)
        }
    }
    
    // Process other changes
    for (windowId, changes) in pendingChanges {
        if changes.contains(.created) {
            // New windows will be handled by refresh detection
            continue
        }
        
        // For moved/resized windows, just invalidate their layout
        if changes.contains(.moved) || changes.contains(.resized) {
            if let window = MacWindow.allWindowsMap[windowId] {
                // Mark window's workspace for re-layout
                window.nodeWorkspace?.markNeedsLayout()
            }
        }
    }
    
    // Still need to check for new windows periodically
    let mapping = try await MacApp.refreshAllAndGetAliveWindowIds(
        frontmostAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    )
    
    // Only register truly new windows
    for (app, windowIds) in mapping {
        for windowId in windowIds {
            if MacWindow.allWindowsMap[windowId] == nil {
                try await MacWindow.getOrRegister(windowId: windowId, macApp: app)
                WindowChangeTracker.shared.trackCreated(windowId: windowId)
            }
        }
    }
    
    Workspace.garbageCollectUnusedWorkspaces()
}

@MainActor
private func refreshFull() async throws {
    // Original full refresh implementation
    let mapping = try await MacApp.refreshAllAndGetAliveWindowIds(frontmostAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    let aliveWindowIds = mapping.values.flatMap { $0 }

    for window in MacWindow.allWindows {
        if !aliveWindowIds.contains(window.windowId) {
            window.garbageCollect(skipClosedWindowsCache: false)
            WindowChangeTracker.shared.trackDestroyed(windowId: window.windowId)
        }
    }
    for (app, windowIds) in mapping {
        for windowId in windowIds {
            if MacWindow.allWindowsMap[windowId] == nil {
                try await MacWindow.getOrRegister(windowId: windowId, macApp: app)
                WindowChangeTracker.shared.trackCreated(windowId: windowId)
            }
        }
    }

    // Garbage collect workspaces after apps, because workspaces contain apps.
    Workspace.garbageCollectUnusedWorkspaces()
}

func refreshObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    let notif = notif as String
    Task { @MainActor in
        if !TrayMenuModel.shared.isEnabled { return }
        runRefreshSession(.ax(notif), screenIsDefinitelyUnlocked: false)
    }
}

enum OptimalHideCorner {
    case bottomLeftCorner, bottomRightCorner
}

@MainActor
private func layoutWorkspaces() async throws {
    if !TrayMenuModel.shared.isEnabled {
        for workspace in Workspace.all {
            workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideFromCorner() } // todo as!
            try await workspace.layoutWorkspace() // Unhide tiling windows from corner
        }
        return
    }
    let monitors = monitors
    var monitorToOptimalHideCorner: [CGPoint: OptimalHideCorner] = [:]
    for monitor in monitors {
        let xOff = monitor.width * 0.1
        let yOff = monitor.height * 0.1
        // brc = bottomRightCorner
        let brc1 = monitor.rect.bottomRightCorner + CGPoint(x: 2, y: -yOff)
        let brc2 = monitor.rect.bottomRightCorner + CGPoint(x: -xOff, y: 2)
        let brc3 = monitor.rect.bottomRightCorner + CGPoint(x: 2, y: 2)

        // blc = bottomLeftCorner
        let blc1 = monitor.rect.bottomLeftCorner + CGPoint(x: -2, y: -yOff)
        let blc2 = monitor.rect.bottomLeftCorner + CGPoint(x: xOff, y: 2)
        let blc3 = monitor.rect.bottomLeftCorner + CGPoint(x: -2, y: 2)

        let corner: OptimalHideCorner =
            monitors.contains(where: { m in m.rect.contains(brc1) || m.rect.contains(brc2) || m.rect.contains(brc3) }) &&
            monitors.allSatisfy { m in !m.rect.contains(blc1) && !m.rect.contains(blc2) && !m.rect.contains(blc3) }
            ? .bottomLeftCorner
            : .bottomRightCorner
        monitorToOptimalHideCorner[monitor.rect.topLeftCorner] = corner
    }

    // to reduce flicker, first unhide visible workspaces, then hide invisible ones
    for monitor in monitors {
        let workspace = monitor.activeWorkspace
        // Only layout if workspace needs it or has pending changes
        if workspace.requiresLayout || WindowChangeTracker.shared.hasPendingChanges() {
            workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideFromCorner() } // todo as!
            try await workspace.layoutWorkspace()
            workspace.clearNeedsLayout()
        }
    }
    for workspace in Workspace.all where !workspace.isVisible {
        // Skip workspaces that don't need updates
        if !workspace.requiresLayout && workspace.isEffectivelyEmpty { continue }
        
        let corner = monitorToOptimalHideCorner[workspace.workspaceMonitor.rect.topLeftCorner] ?? .bottomRightCorner
        for window in workspace.allLeafWindowsRecursive {
            try await (window as! MacWindow).hideInCorner(corner) // todo as!
        }
    }
}

@MainActor
private func normalizeContainers() {
    // Can't do it only for visible workspace because most of the commands support --window-id and --workspace flags
    for workspace in Workspace.all {
        workspace.normalizeContainers()
    }
}
