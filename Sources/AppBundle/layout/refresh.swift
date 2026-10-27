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
    if !TrayMenuModel.shared.isEnabled { return }
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
        let focusBefore = focus.windowOrNil

        await refreshModel_nonCancellable()
        let result = try await body()
        await refreshModel_nonCancellable()

        let focusAfter = focus.windowOrNil

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

struct RunSessionGuard: Sendable {
    @MainActor
    static var isServerEnabled: RunSessionGuard? { TrayMenuModel.shared.isEnabled ? forceRun : nil }
    @MainActor
    static func isServerEnabled(orIsEnableCommand command: (any Command)?) -> RunSessionGuard? {
        command is EnableCommand ? .forceRun : .isServerEnabled
    }
    @MainActor
    static func checkServerIsEnabledOrDie(
        file: StaticString = #fileID,
        line: Int = #line,
        column: Int = #column,
        function: String = #function,
    ) -> RunSessionGuard {
        .isServerEnabled ?? dieT("server is disabled", file: file, line: line, column: column, function: function)
    }
    static let forceRun = RunSessionGuard()
    private init() {}
}

@MainActor
func refreshModel_nonCancellable() async {
    if refreshSessionEvent?.isFocusFollowsMouse == true {
        await checkOnFocusChangedCallbacks_nonCancellable()
    } else {
        Workspace.garbageCollectUnusedWorkspaces()
        await checkOnFocusChangedCallbacks_nonCancellable()
        normalizeContainers()
    }
}

@MainActor
private func refresh() async throws {
    // Garbage collect terminated apps and windows before working with all windows
    let mapping = try await MacApp.refreshAllAndGetAliveWindowIds(frontmostAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    let aliveWindowIds = mapping.values.flatMap(id).toSet()

    for window in MacWindow.allWindows {
        if !aliveWindowIds.contains(window.windowId) {
            window.garbageCollect(skipClosedWindowsCache: false)
        }
    }
    for (app, windowIds) in mapping {
        for windowId in windowIds {
            try await MacWindow.getOrRegister(windowId: windowId, macApp: app)
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

/// Which bottom corner should a hidden window of `monitorRect` be parked at?
///
/// The two corners spill in DIFFERENT directions (see MacWindow.hideInCorner):
///  - bottomRight: the window's top-left sits at the corner and its body extends RIGHT and DOWN
///  - bottomLeft:  the window's body extends LEFT and DOWN
/// so which corner is safer depends entirely on where the other displays are. The original
/// scoring only probed six points around each corner, never the body — a large window (Spotify is
/// 2550x1067 on this machine) therefore scored "invisible" while a slice of it sat on a
/// neighbouring display, which shows up as a flicker of another workspace that depends purely on
/// display geometry.
///
/// Pure over rects so the decision is unit testable with synthetic display arrangements.
func optimalHideCorner(monitorRect: Rect, allMonitorRects: [Rect]) -> OptimalHideCorner {
    let xOff = monitorRect.width * 0.1
    let yOff = monitorRect.height * 0.1
    let brc = monitorRect.bottomRightCorner
    let blc = monitorRect.bottomLeftCorner

    let brc1 = brc + CGPoint(x: 2, y: -yOff)
    let brc2 = brc + CGPoint(x: -xOff, y: 2)
    let brc3 = brc + CGPoint(x: 2, y: 2)

    let blc1 = blc + CGPoint(x: -2, y: -yOff)
    let blc2 = blc + CGPoint(x: xOff, y: 2)
    let blc3 = blc + CGPoint(x: -2, y: 2)

    func contains(_ rect: Rect, _ point: CGPoint) -> Int { rect.contains(point) ? 1 : 0 }
    let important = 10

    /// How many OTHER displays the parked body would reach.
    func spillCount(_ corner: CGPoint, extendsRight: Bool) -> Int {
        allMonitorRects.count(where: { other in
            guard other.topLeftCorner != monitorRect.topLeftCorner else { return false }
            let xReached = extendsRight
                ? other.bottomRightCorner.x > corner.x      // body runs to the right of the corner
                : other.topLeftCorner.x < corner.x           // body runs to the left of the corner
            return xReached && other.bottomRightCorner.y > corner.y   // ...and below it
        })
    }

    let blcScore = allMonitorRects.sumOfInt { contains($0, blc1) + contains($0, blc2) + important * contains($0, blc3) }
        + important * spillCount(blc, extendsRight: false)
    let brcScore = allMonitorRects.sumOfInt { contains($0, brc1) + contains($0, brc2) + important * contains($0, brc3) }
        + important * spillCount(brc, extendsRight: true)

    // Tie keeps bottom-right, i.e. exactly the previous behaviour when no corner is safe.
    return blcScore < brcScore ? .bottomLeftCorner : .bottomRightCorner
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
    let monitors = monitorInfos
    var monitorToOptimalHideCorner: [CGPoint: OptimalHideCorner] = [:]
    let allRects = monitors.map(\.rect)
    for monitor in monitors {
        monitorToOptimalHideCorner[monitor.rect.topLeftCorner] =
            optimalHideCorner(monitorRect: monitor.rect, allMonitorRects: allRects)
    }

    // to reduce flicker, first unhide visible workspaces, then hide invisible ones
    for monitor in monitors {
        let workspace = monitor.activeWorkspace
        workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideFromCorner() } // todo as!
        try await workspace.layoutWorkspace()
    }
    for workspace in Workspace.all where !workspace.isVisible {
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
