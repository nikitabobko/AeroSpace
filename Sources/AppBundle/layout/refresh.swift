import AppKit
import Common

@MainActor
private var activeRefreshTask: Task<(), any Error>? = nil

@MainActor
private var isRunningLightSession = false

@MainActor
func cancelActiveRefreshTask() {
    activeRefreshTask?.cancel()
    activeRefreshTask = nil
}

@MainActor
func scheduleCancellableCompleteRefreshSession(
    _ event: RefreshSessionEvent,
    optimisticallyPreLayoutWorkspaces: Bool = false,
) {
    if !isUnitTest && isRunningLightSession { return }
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

            if shouldLayoutWorkspaces && optimisticallyPreLayoutWorkspaces { try await layoutWorkspaces(allowAutoHide: false) }

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
    if !isUnitTest && event.isReadOnlyOrExecAndForget {
        return try await $refreshSessionEvent.withValue(event) {
            try await body()
        }
    }
    activeRefreshTask?.cancel() // Give priority to runSession
    activeRefreshTask = nil
    isRunningLightSession = true
    defer { isRunningLightSession = false }
    return try await $refreshSessionEvent.withValue(event) {
        if isUnitTest || !event.isWorkspaceSwitch {
            let nativeFocused = try await getNativeFocusedWindow(.cancellable)
            if let nativeFocused { try await debugWindowsIfRecording(nativeFocused, .cancellable) }
            updateFocusCache(nativeFocused)
        }
        let focusBefore = focus.windowOrNil

        await refreshModel_nonCancellable()
        let result = try await body()
        await refreshModel_nonCancellable()

        let focusAfter = focus.windowOrNil
        let isExplicitFocusCommand = if case .socketServer(let args) = event { args is FocusCmdArgs } else { false }
        let focusToSync = (focusBefore != focusAfter || isExplicitFocusCommand) ? focusAfter : nil

        if !event.isFocusFollowsMouse {
            try await layoutWorkspaces(focusToSync: focusToSync)
        } else {
            focusToSync?.nativeFocus() // syncFocusToMacOs
        }
        updateTrayText()
        SecureInputPanel.shared.refresh()
        isRunningLightSession = false
        if !event.isFocusFollowsMouse && (isUnitTest || !event.isWorkspaceSwitch) {
            scheduleCancellableCompleteRefreshSession(event)
        }
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
    let pid = axTaskLocalAppThreadToken?.pid
    Task.startUnstructured { @MainActor in
        if !TrayMenuModel.shared.isEnabled { return }
        if let pid, let app = MacApp.allAppsMap[pid] {
            if notif == kAXWindowCreatedNotification || notif == kAXUIElementDestroyedNotification {
                app.needsWindowRefresh = true
            }
            if notif == kAXWindowCreatedNotification {
                app.markExternallyUnhiddenOrActivated()
                app.unhideIfHiddenByAeroSpace(forceIfHidden: true)
            }
        }
        if notif == kAXFocusedWindowChangedNotification {
            if let pid, let app = MacApp.allAppsMap[pid], app.isSuppressingSelfFocusNotifications {
                return
            }
            if let focusedMacWindow = focus.windowOrNil as? MacWindow,
               focusedMacWindow.macApp.pid == pid,
               focusedMacWindow.macApp.isSuppressingSelfFocusNotifications
            {
                return
            }
        }
        scheduleCancellableCompleteRefreshSession(.ax(notif))
    }
}

enum OptimalHideCorner {
    case bottomLeftCorner, bottomRightCorner
}

@MainActor
private func layoutWorkspaces(allowAutoHide: Bool = true, focusToSync: Window? = nil) async throws {
    if !TrayMenuModel.shared.isEnabled {
        for app in MacApp.allAppsMap.values {
            app.unhideIfHiddenByAeroSpace()
        }
        HideCornerOccluder.shared.hideAll()
        for workspace in Workspace.all {
            workspace.allLeafWindowsRecursiveMru.forEach { ($0 as! MacWindow).unhideFromCorner() } // todo as!
            try await workspace.layoutWorkspace() // Unhide tiling windows from corner
        }
        focusToSync?.nativeFocus()
        return
    }
    let monitors = monitorInfos
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

        func contains(_ monitor: MonitorInfo, _ point: CGPoint) -> Int { monitor.rect.contains(point) ? 1 : 0 }
        let important = 10

        let corner: OptimalHideCorner =
            monitors.sumOfInt { contains($0, blc1) + contains($0, blc2) + important * contains($0, blc3) } <
            monitors.sumOfInt { contains($0, brc1) + contains($0, brc2) + important * contains($0, brc3) }
            ? .bottomLeftCorner
            : .bottomRightCorner
        monitorToOptimalHideCorner[monitor.rect.topLeftCorner] = corner
    }

    // to reduce flicker, first unhide visible workspaces, then hide invisible ones
    var didSyncFocus = false
    var monitorsWithHiddenWindows: Set<CGPoint> = []
    for monitor in monitors {
        let workspace = monitor.activeWorkspace
        let mruWindows = workspace.allLeafWindowsRecursiveMru.map { $0 as! MacWindow } // todo as!

        for node in workspace.macOsNativeFullscreenWindowsContainer.children {
            (node as? MacWindow)?.macApp.unhideIfHiddenByAeroSpace(forceIfHidden: true)
        }

        for macWindow in mruWindows {
            macWindow.macApp.unhideIfHiddenByAeroSpace(forceIfHidden: true)
        }

        for macWindow in mruWindows {
            macWindow.unhideFromCorner()
            if let focusToSync, macWindow == focusToSync {
                focusToSync.nativeFocus()
                didSyncFocus = true
            }
        }
        try await workspace.layoutWorkspace()
    }
    if !didSyncFocus {
        focusToSync?.nativeFocus()
    }
    for workspace in Workspace.all where !workspace.isVisible {
        let monitorOrigin = workspace.workspaceMonitor.rect.topLeftCorner
        let corner = monitorToOptimalHideCorner[monitorOrigin] ?? .bottomRightCorner
        let windows = workspace.allLeafWindowsRecursive
        if !windows.isEmpty {
            monitorsWithHiddenWindows.insert(monitorOrigin)
        }
        for window in windows {
            try await (window as! MacWindow).hideInCorner(corner) // todo as!
        }
    }
    HideCornerOccluder.shared.update(
        monitors: monitors,
        monitorToOptimalHideCorner: monitorToOptimalHideCorner,
        monitorsWithHiddenWindows: monitorsWithHiddenWindows,
    )
    for app in MacApp.allAppsMap.values {
        if app.isEligibleForAeroSpaceAutoHide() {
            if allowAutoHide {
                app.scheduleHideByAeroSpaceIfEligible()
            }
        } else {
            app.unhideIfHiddenByAeroSpace()
        }
    }
}

private func isRectCompletelyCovered(_ target: Rect, by frontRects: [Rect]) -> Bool {
    guard !frontRects.isEmpty else { return false }
    let inset: CGFloat = 4
    let shrunk = Rect(
        topLeftX: target.minX + inset,
        topLeftY: target.minY + inset,
        width: max(0, target.width - inset * 2),
        height: max(0, target.height - inset * 2),
    )
    if shrunk.width <= 0 || shrunk.height <= 0 { return true }
    var remaining: [Rect] = [shrunk]
    for front in frontRects {
        var nextRemaining: [Rect] = []
        for r in remaining {
            if front.maxX <= r.minX || front.minX >= r.maxX || front.maxY <= r.minY || front.minY >= r.maxY {
                nextRemaining.append(r)
                continue
            }
            if front.minY > r.minY {
                nextRemaining.append(Rect(topLeftX: r.minX, topLeftY: r.minY, width: r.width, height: front.minY - r.minY))
            }
            if front.maxY < r.maxY {
                nextRemaining.append(Rect(topLeftX: r.minX, topLeftY: front.maxY, width: r.width, height: r.maxY - front.maxY))
            }
            let clampedMinY = max(r.minY, front.minY)
            let clampedMaxY = min(r.maxY, front.maxY)
            let midHeight = clampedMaxY - clampedMinY
            if midHeight > 0 {
                if front.minX > r.minX {
                    nextRemaining.append(Rect(topLeftX: r.minX, topLeftY: clampedMinY, width: front.minX - r.minX, height: midHeight))
                }
                if front.maxX < r.maxX {
                    nextRemaining.append(Rect(topLeftX: front.maxX, topLeftY: clampedMinY, width: r.maxX - front.maxX, height: midHeight))
                }
            }
        }
        remaining = nextRemaining
        if remaining.isEmpty {
            return true
        }
    }
    return remaining.isEmpty
}

@MainActor
private func normalizeContainers() {
    // Can't do it only for visible workspace because most of the commands support --window-id and --workspace flags
    for workspace in Workspace.all {
        workspace.normalizeContainers()
    }
}
