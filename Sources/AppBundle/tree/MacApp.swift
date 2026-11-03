import AppKit
import Common

// Potential alternative implementation
// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md
// (only available since #macos14)
final class MacApp: AbstractApp {
    /*conforms*/ let pid: Int32
    /*conforms*/ let rawAppBundleId: String?
    let appId: KnownBundleId?
    let nsApp: NSRunningApplication
    private let axApp: ThreadGuardedValue<AXUIElement>
    private let appAxSubscriptions: ThreadGuardedValue<[AxSubscription]> // keep subscriptions in memory
    private let windows: ThreadGuardedValue<[UInt32: AxWindow]> = .init([:])
    private var windowsCount = 0
    var lastFocusedNativeWindowOpaqueId: OpaqueWindowId? = nil
    @MainActor var isHiddenByAeroSpace: Bool = false
    @MainActor var isUserHidden: Bool {
        if !isUnitTest && !config.automaticallyUnhideMacosHiddenApps {
            return false
        }
        return nsApp.isHidden && !isHiddenByAeroSpace
    }
    @MainActor private var hideTaskGeneration: UInt64 = 0
    @MainActor private var isAutoHideTaskPending: Bool = false
    @MainActor private var suppressNextHideNotification: Bool = false
    @MainActor private var suppressNextUnhideNotification: Bool = false
    @MainActor private var preventAutoHideUntil: ContinuousClock.Instant? = nil
    @MainActor static var lastAeroSpaceActiveAppHideTime: ContinuousClock.Instant? = nil
    @MainActor private var inFlightFocusJobsCount: Int = 0
    @MainActor private var lastNativeFocusTime: ContinuousClock.Instant? = nil
    @MainActor private(set) var isDetachingTabToNewWindow: Bool = false
    @MainActor private var cachedAliveWindowIds: [OpaqueWindowId: WindowLifeStatus] = [:]
    @MainActor private var hasCompletedInitialWindowRefresh: Bool = false
    @MainActor var needsWindowRefresh: Bool = false
    @MainActor private var cachedTitles: [UInt32: String] = [:]
    @MainActor private var isCheckingChromeTabMenu: Bool = false
    @MainActor fileprivate var lastChromeTabMenuSnapshot: ChromeTabMenuSnapshot? = nil
    private var thread: Thread?
    private var setFrameJobs: [OpaqueWindowId: RunLoopJob] = [:]
    // Never pruned: while the screen is locked, AX reports windows as gone, and closedWindowsCache matches
    // the windows re-detected after unlock by their OpaqueWindowId
    // todo: start prunning after we get rid of closedWindowsCache
    private var windowIdMapping = BiDictionary<OpaqueWindowId, UInt32>()
    @MainActor private static var focusJob: RunLoopJob? = nil

    /*conforms*/ var name: String? { nsApp.localizedName }
    /*conforms*/ var execPath: String? { nsApp.executableURL?.path }
    /*conforms*/ var bundlePath: String? { nsApp.bundleURL?.path }

    // todo think if it's possible to integrate this global mutable state to https://github.com/nikitabobko/AeroSpace/issues/1215
    //      and make deinitialization automatic in deinit
    @MainActor static var allAppsMap: [pid_t: MacApp] = [:]
    @MainActor private static var wipPids: [pid_t: AwaitableOneTimeBroadcastLatch] = [:]

    private init(
        _ nsApp: NSRunningApplication,
        _ axApp: AXUIElement,
        _ axSubscriptions: [AxSubscription],
        _ thread: Thread,
    ) {
        self.nsApp = nsApp
        self.axApp = .init(axApp)
        self.pid = nsApp.processIdentifier
        self.rawAppBundleId = nsApp.bundleIdentifier
        self.appId = nsApp.bundleIdentifier.flatMap { KnownBundleId.init(rawValue: $0) }
        assert(!axSubscriptions.isEmpty)
        self.appAxSubscriptions = .init(axSubscriptions)
        self.thread = thread
    }

    @MainActor @discardableResult static func getOrRegister(_ nsApp: NSRunningApplication) async throws -> MacApp? {
        // Don't perceive any of the lock screen windows as real windows
        // Otherwise, false positive ax notifications might trigger that lead to gcWindows
        if nsApp.bundleIdentifier == lockScreenAppBundleId { return nil }
        let pid = nsApp.processIdentifier
        // AX requests crash if you send them to yourself
        if pid == myPid { return nil }

        if let existing = allAppsMap[pid] { return existing }
        try checkCancellation()
        if let wip = wipPids[pid] {
            try await wip.await(.cancellable)
            return allAppsMap[pid]
        }
        let wip = AwaitableOneTimeBroadcastLatch()
        wipPids[pid] = wip

        let thread = Thread {
            $axTaskLocalAppThreadToken.withValue(AxAppThreadToken(pid: pid, idForDebug: nsApp.idForDebug)) {
                let axApp = AXUIElementCreateApplication(nsApp.processIdentifier)
                AXUIElementSetMessagingTimeout(axApp, 0.5)
                AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.5)
                let handlers: HandlerToNotifKeyMapping = unsafe [
                    (refreshObs, [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification]),
                ]
                let job = RunLoopJob(.cancellable)
                let subscriptions = (try? unsafe AxSubscription.bulkSubscribe(nsApp, axApp, job, handlers)) ?? []
                let isGood = !subscriptions.isEmpty
                let app = isGood ? MacApp(nsApp, axApp, subscriptions, Thread.current) : nil

                let appAxSubscriptionsThreadGuarded = app?.appAxSubscriptions
                let windowsThreadGuarded = app?.windows
                let axAppThreadGuarded = app?.axApp
                let initialChromeSnap = nsApp.bundleIdentifier == "com.google.Chrome" ? readChromeTabMenuSnapshot(axApp) : nil

                Task.startUnstructured { @MainActor in
                    if let app, isStartup && nsApp.isHidden {
                        app.isHiddenByAeroSpace = true
                    }
                    app?.lastChromeTabMenuSnapshot = initialChromeSnap
                    allAppsMap[pid] = app
                    wipPids[pid] = nil
                    await wip.signalToAll()
                }
                if isGood {
                    CFRunLoopRun()

                    // Destroy AX objects in reverse order of their creation
                    appAxSubscriptionsThreadGuarded?.destroy()
                    windowsThreadGuarded?.destroy()
                    axAppThreadGuarded?.destroy()
                }
            }
        }
        thread.name = "AxAppThread \(nsApp.idForDebug)"
        thread.start()

        try await wip.await(.cancellable)
        return allAppsMap[pid]
    }

    func nativeWindowId(of windowId: OpaqueWindowId) -> UInt32? { windowIdMapping.forward[windowId] }

    func opaqueWindowId(of nativeWindowId: UInt32) -> OpaqueWindowId? { windowIdMapping.backward[nativeWindowId] }

    @MainActor private func getOrRegisterOpaqueWindowId(_ nativeWindowId: UInt32) -> OpaqueWindowId {
        if let existing = windowIdMapping.backward[nativeWindowId] { return existing }
        let candidate = OpaqueWindowId(UInt64(nativeWindowId))
        let windowId = windowIdMapping.forward[candidate] == nil ? candidate : OpaqueWindowId.nextUniqId()
        windowIdMapping.put(windowId, nativeWindowId)
        return windowId
    }

    func closeAndUnregisterAxWindow(_ windowId: OpaqueWindowId) {
        if serverArgs.isReadOnly { return }
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        guard let nativeWindowId = windowIdMapping.forward[windowId] else { return }
        _ = withWindowAsync(windowId, .cancellable) { [windows] window, job in
            guard let closeButton = window.get(Ax.closeButtonAttr) else { return }
            if AXUIElementPerformAction(closeButton.cast, kAXPressAction as CFString) == .success {
                windows.threadGuarded.removeValue(forKey: nativeWindowId)
            }
        }
    }

    func getAxSize(_ windowId: OpaqueWindowId, _ cm: CancellationMode) async throws -> CGSize? {
        try await withWindow(windowId, cm) { window, job in
            window.get(Ax.sizeAttr)
        }
    }

    // todo merge together with detectNewWindows
    func getFocusedWindow(_ cm: CancellationMode) async throws -> Window? {
        let nativeWindowId = try await thread?.runInLoop(cm) { [nsApp, axApp, windows] job in
            try axApp.threadGuarded.get(Ax.focusedWindowAttr)
                .flatMap { try windows.threadGuarded.getOrRegisterAxWindow(windowId: $0.windowId, $0.ax.cast, nsApp, job) }?
                .windowId
        }
        guard let nativeWindowId else { return nil }
        return try await MacWindow.getOrRegister(windowId: getOrRegisterOpaqueWindowId(nativeWindowId), macApp: self)
    }

    @MainActor func nativeFocus(_ windowId: OpaqueWindowId) {
        if serverArgs.isReadOnly { return }
        unhideIfHiddenByAeroSpace(forceIfHidden: true)
        MacApp.focusJob?.cancel()
        recordAeroSpaceNativeFocus(windowId, app: self)
        inFlightFocusJobsCount += 1
        lastNativeFocusTime = .now
        let pid = self.pid
        MacApp.focusJob = withWindowAsync(windowId, .cancellable, onComplete: {
            Task.startUnstructured { @MainActor in
                if let app = MacApp.allAppsMap[pid] {
                    app.inFlightFocusJobsCount = max(0, app.inFlightFocusJobsCount - 1)
                    app.lastNativeFocusTime = .now
                    if app.rawAppBundleId == "com.google.Chrome" {
                        app.refreshChromeTabMenuSnapshotAsync()
                    }
                    if app.inFlightFocusJobsCount == 0 && NSWorkspace.shared.frontmostApplication?.processIdentifier == pid {
                        onAppActivatedInWorkspace(pid)
                    }
                }
            }
        }) { [nsApp] window, _ in
            // Raise firstly to make sure that by the time we activate the app, the window would be already on top
            window.set(Ax.isMainAttr, true)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            nsApp.activate(options: .activateIgnoringOtherApps)
        }
    }

    @MainActor
    func refreshChromeTabMenuSnapshotAsync() {
        guard rawAppBundleId == "com.google.Chrome", !isUnitTest, !serverArgs.isReadOnly, !isDetachingTabToNewWindow else { return }
        let pid = self.pid
        _ = thread?.runInLoopAsync(job: RunLoopJob(.cancellable), autoCheckCancelled: false) { [axApp] _ in
            guard let snap = readChromeTabMenuSnapshot(axApp.threadGuarded) else { return }
            Task.startUnstructured { @MainActor in
                if let app = MacApp.allAppsMap[pid], !app.isDetachingTabToNewWindow {
                    app.lastChromeTabMenuSnapshot = snap
                }
            }
        }
    }

    @MainActor
    func checkForNewlyOpenedExternalChromeTab(hintWindowId: UInt32? = nil) async {
        guard rawAppBundleId == "com.google.Chrome",
              !isUnitTest,
              !serverArgs.isReadOnly,
              !isDetachingTabToNewWindow,
              !isCheckingChromeTabMenu,
              let thread
        else { return }
        isCheckingChromeTabMenu = true
        defer { isCheckingChromeTabMenu = false }

        guard let snap = try? await thread.runInLoop(.cancellable, { [axApp] _ in
            readChromeTabMenuSnapshot(axApp.threadGuarded)
        }) else { return }

        guard let prev = lastChromeTabMenuSnapshot else {
            lastChromeTabMenuSnapshot = snap
            return
        }
        let sameWindow = prev.mainWindowId == nil || snap.mainWindowId == nil || snap.mainWindowId == prev.mainWindowId
        let isNewSelectedTabAtEnd =
            sameWindow &&
            snap.tabs.count == prev.tabs.count + 1 &&
            snap.tabs.count >= 2 &&
            snap.checkedIndex == snap.tabs.count - 1
        lastChromeTabMenuSnapshot = snap
        guard isNewSelectedTabAtEnd else { return }

        let targetOpaqueId: OpaqueWindowId? = (snap.mainWindowId ?? hintWindowId).flatMap { opaqueWindowId(of: $0) }
            ?? lastFocusedNativeWindowOpaqueId
        let targetWin = targetOpaqueId.flatMap { MacWindow.allWindowsMap[$0] }
        let winWorkspace = targetWin?.nodeWorkspace

        if winWorkspace == nil || winWorkspace?.isVisible == false {
            let nativeFromId = snap.mainWindowId ?? hintWindowId ?? targetOpaqueId.flatMap { nativeWindowId(of: $0) }
            await detachActiveChromeTabToNewWindow(fromWindowId: nativeFromId)
        } else if winWorkspace?.isVisible == true,
                  globalFocus.windowOrNil?.app.rawAppBundleId != "com.google.Chrome",
                  let targetWin,
                  let token: RunSessionGuard = .isServerEnabled
        {
            _ = try? await runLightSession(.globalObserver("ChromeExternalLinkTab"), token) {
                _ = targetWin.focusWindow()
            }
        }
    }

    @MainActor
    private func detachActiveChromeTabToNewWindow(fromWindowId: UInt32?) async {
        guard !isDetachingTabToNewWindow, let thread else { return }
        isDetachingTabToNewWindow = true
        defer { isDetachingTabToNewWindow = false }

        let targetWorkspace = globalFocus.workspace
        unhideIfHiddenByAeroSpace(forceIfHidden: true)
        if !nsApp.isActive {
            nsApp.activate(options: .activateIgnoringOtherApps)
        }

        let result = try? await thread.runInLoop(.cancellable) { [axApp, windows] _ -> (UInt32?, ChromeTabMenuSnapshot?) in
            let appEl = axApp.threadGuarded
            let oldWindowIds = Set(appEl.get(Ax.windowsAttr)?.map(\.windowId) ?? [])
            if let fromWindowId, let axWin = windows.threadGuarded[fromWindowId]?.ax {
                axWin.set(Ax.isMainAttr, true)
                AXUIElementPerformAction(axWin, kAXRaiseAction as CFString)
            }
            var didPress = false
            for _ in 0 ..< 15 {
                if let moveItem = findMoveTabToNewWindowMenuItem(appEl),
                   moveItem.get(Ax.enabledAttr) == true
                {
                    _ = AXUIElementPerformAction(moveItem, kAXPressAction as CFString)
                    didPress = true
                    break
                }
                Thread.sleep(forTimeInterval: 0.015)
            }
            var newWindowId: UInt32? = nil
            if didPress {
                for _ in 0 ..< 15 {
                    Thread.sleep(forTimeInterval: 0.02)
                    if let currentWins = appEl.get(Ax.windowsAttr),
                       let created = currentWins.first(where: { !oldWindowIds.contains($0.windowId) })
                    {
                        newWindowId = created.windowId
                        break
                    }
                }
            }
            return (newWindowId, readChromeTabMenuSnapshot(appEl))
        }

        if let postSnap = result?.1 {
            lastChromeTabMenuSnapshot = postSnap
        }
        needsWindowRefresh = true
        await runHeavyCompleteRefreshSession(.ax(kAXWindowCreatedNotification), assumeCancellable: false)
        if let newNativeWindowId = result?.0,
           let newOpaqueId = opaqueWindowId(of: newNativeWindowId),
           let newWin = MacWindow.allWindowsMap[newOpaqueId],
           let token: RunSessionGuard = .isServerEnabled
        {
            _ = try? await runLightSession(.ax(kAXWindowCreatedNotification), token) {
                if newWin.nodeWorkspace != targetWorkspace {
                    let targetParent: NonLeafTreeNodeObject = newWin.isFloating
                        ? targetWorkspace.floatingWindowsContainer
                        : targetWorkspace.rootTilingContainer
                    _ = newWin.bind(to: targetParent, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
                }
                newWin.unhideFromCorner()
                _ = newWin.focusWindow()
            }
        }
    }

    @MainActor
    var isSuppressingSelfFocusNotifications: Bool {
        if inFlightFocusJobsCount > 0 { return true }
        if let lastNativeFocusTime, lastNativeFocusTime.duration(to: .now) < .milliseconds(500) {
            return true
        }
        return false
    }

    @MainActor
    func unhideIfHiddenByAeroSpace(forceIfHidden: Bool = false) {
        hideTaskGeneration &+= 1
        isAutoHideTaskPending = false
        let shouldUnhide = isHiddenByAeroSpace || (forceIfHidden && !isUnitTest && !config.automaticallyUnhideMacosHiddenApps && nsApp.isHidden)
        guard shouldUnhide else { return }
        isHiddenByAeroSpace = false
        if !isUnitTest && !serverArgs.isReadOnly && nsApp.isHidden {
            suppressNextUnhideNotification = true
            nsApp.unhide()
            _ = thread?.runInLoopAsync(job: RunLoopJob(.cancellable), autoCheckCancelled: false) { [axApp] _ in
                _ = AXUIElementSetAttributeValue(axApp.threadGuarded, kAXHiddenAttribute as CFString, kCFBooleanFalse)
            }
            Task.startUnstructured { @MainActor [weak self] in
                for delayMs in [60, 180] {
                    try? await Task.sleep(for: .milliseconds(delayMs))
                    guard let self, !self.nsApp.isHidden else { return }
                    for workspace in Workspace.all where !workspace.isVisible {
                        for window in workspace.allLeafWindowsRecursive where window.app.pid == self.pid {
                            let macWin = window as! MacWindow
                            if !macWin.isCurrentlyInHideCorner() {
                                try? await macWin.hideInCorner(.bottomRightCorner)
                            }
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func consumeSuppressedHideNotification() -> Bool {
        if suppressNextHideNotification {
            suppressNextHideNotification = false
            return true
        }
        return isHiddenByAeroSpace
    }

    @MainActor
    func consumeSuppressedUnhideNotification() -> Bool {
        if suppressNextUnhideNotification {
            suppressNextUnhideNotification = false
            return true
        }
        return false
    }

    @MainActor
    func markExternallyUnhiddenOrActivated() {
        needsWindowRefresh = true
        guard isHiddenByAeroSpace else { return }
        hideTaskGeneration &+= 1
        isAutoHideTaskPending = false
        isHiddenByAeroSpace = false
        preventAutoHideUntil = ContinuousClock.now.advanced(by: .seconds(1))
    }

    @MainActor
    func scheduleHideByAeroSpaceIfEligible() {
        if isUnitTest || serverArgs.isReadOnly || !TrayMenuModel.shared.isEnabled { return }
        if let until = preventAutoHideUntil, ContinuousClock.now < until { return }
        if isHiddenByAeroSpace && nsApp.isHidden { return }
        if nsApp.isHidden { return } // Already hidden by the user (Cmd+H)
        if isAutoHideTaskPending { return }

        hideTaskGeneration &+= 1
        isAutoHideTaskPending = true
        let generation = hideTaskGeneration
        Task.startUnstructured { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.hideTaskGeneration == generation {
                    self.isAutoHideTaskPending = false
                }
            }
            // Wait for any pending corner setAxFrame jobs queued on this app's AX thread
            // so all windows are parked in the hide corner before hiding the app.
            _ = try? await self.thread?.runInLoop(.cancellable) { _ in () }
            if self.nsApp.isActive {
                try? await Task.sleep(for: .milliseconds(120))
            }
            guard self.hideTaskGeneration == generation,
                  TrayMenuModel.shared.isEnabled,
                  !serverArgs.isReadOnly,
                  !self.nsApp.isTerminated,
                  !self.nsApp.isHidden
            else { return }
            if let until = self.preventAutoHideUntil, ContinuousClock.now < until { return }
            guard self.isEligibleForAeroSpaceAutoHide() else { return }
            if self.nsApp.isActive {
                MacApp.lastAeroSpaceActiveAppHideTime = .now
            }
            self.isHiddenByAeroSpace = true
            self.suppressNextHideNotification = true
            self.nsApp.hide()
        }
    }

    @MainActor
    func isEligibleForAeroSpaceAutoHide() -> Bool {
        if needsWindowRefresh || isDetachingTabToNewWindow { return false }
        if globalFocus.windowOrNil?.app.pid == pid || stickyClosedAppPidOnCurrentWorkspace == pid || (globalFocus.windowOrNil == nil && nsApp.isActive) { return false }
        for node in macosPopupWindowsContainer.children {
            if (node as? Window)?.app.pid == pid { return false }
        }
        var hasInvisibleWorkspaceWindows = false
        for workspace in Workspace.all {
            for window in workspace.allLeafWindowsRecursive where window.app.pid == pid {
                if workspace.isVisible {
                    return false
                }
                hasInvisibleWorkspaceWindows = true
            }
            if workspace.macOsNativeFullscreenWindowsContainer.children.contains(where: { ($0 as? Window)?.app.pid == pid }) {
                if workspace.isVisible {
                    return false
                }
                hasInvisibleWorkspaceWindows = true
            }
            if workspace.macOsNativeHiddenAppsWindowsContainer.children.contains(where: { ($0 as? Window)?.app.pid == pid }) {
                return false
            }
        }
        return hasInvisibleWorkspaceWindows
    }

    func waitForPendingAxJobs() async {
        if isUnitTest || serverArgs.isReadOnly { return }
        _ = try? await thread?.runInLoop(.cancellable) { _ in () }
    }

    func setAxFrame(_ windowId: OpaqueWindowId, _ topLeft: CGPoint?, _ size: CGSize?) {
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        setFrameJobs[windowId] = withWindowAsync(windowId, .cancellable, onComplete: {
            Task.startUnstructured { @MainActor in
                if let win = MacWindow.allWindowsMap[windowId] {
                    win.inFlightSetFrameCount = max(0, win.inFlightSetFrameCount - 1)
                    win.lastSetFrameTime = .now
                }
            }
        }) { [axApp] window, job in
            if size != nil {
                try disableAnimations(app: axApp.threadGuarded, job) {
                    try setFrame(window, topLeft, size, job)
                }
            } else {
                try setFrame(window, topLeft, nil, job)
            }
        }
    }

    func setAxFrameForTermination(_ windowId: OpaqueWindowId, _ topLeft: CGPoint?, _ size: CGSize?) {
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        let semaphore = DispatchSemaphore(value: 0)
        let job = withWindowAsync(windowId, .nonCancellable) { [axApp] window, job in
            try? disableAnimations(app: axApp.threadGuarded, job) {
                try setFrame(window, topLeft, size, job)
            }
            semaphore.signal()
        }
        switch job.isCancelled {
            case true: return
            case false: semaphore.wait()
        }
    }

    func getAxWindowsCount(_ cm: CancellationMode) async throws -> Int? {
        try await thread?.runInLoop(cm) { [axApp] job in
            axApp.threadGuarded.get(Ax.windowsAttr)?.count
        }
    }

    func getAxRect(_ windowId: OpaqueWindowId, _ cm: CancellationMode) async throws -> Rect? {
        try await withWindow(windowId, cm) { window, job in
            try AppBundle::getAxRect(window: window, job: job)
        }
    }

    func getAxRectForTermination(_ windowId: OpaqueWindowId) -> Rect? {
        let future = CompletableFuture<Rect?>()
        let job = withWindowAsync(windowId, .nonCancellable) { window, job in
            future.complete(try AppBundle::getAxRect(window: window, job: job))
        }
        return switch job.isCancelled {
            case true: nil
            case false: future.blockingGet()
        }
    }

    func isWindowHeuristic(_ windowId: OpaqueWindowId, _ windowLevel: MacOsWindowLevel?, _ cm: CancellationMode) async throws -> Bool {
        return try await withWindow(windowId, cm) { [nsApp, axApp, appId] window, job in
            window.isWindowHeuristic(axApp: axApp.threadGuarded, appId, nsApp.activationPolicy, windowLevel)
        } == true
    }

    func getAxUiElementWindowType(_ windowId: OpaqueWindowId, _ windowLevel: MacOsWindowLevel?, _ cm: CancellationMode) async throws -> AxUiElementWindowType {
        return try await withWindow(windowId, cm) { [nsApp, axApp, appId] window, job in
            window.getWindowType(axApp: axApp.threadGuarded, appId, nsApp.activationPolicy, windowLevel)
        } ?? .window
    }

    func isDialogHeuristic(_ windowId: OpaqueWindowId, _ windowLevel: MacOsWindowLevel?, _ cm: CancellationMode) async throws -> Bool {
        try await withWindow(windowId, cm) { [appId] window, job in
            window.isDialogHeuristic(appId, windowLevel)
        } == true
    }

    func setNativeFullscreen(_ windowId: OpaqueWindowId, _ value: Bool) {
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        setFrameJobs[windowId] = withWindowAsync(windowId, .cancellable) { window, job in
            window.set(Ax.isFullscreenAttr, value)
        }
    }

    func setNativeMinimized(_ windowId: OpaqueWindowId, _ value: Bool) {
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        setFrameJobs[windowId] = withWindowAsync(windowId, .cancellable) { window, job in
            window.set(Ax.minimizedAttr, value)
        }
    }

    func dumpWindowAxInfo(windowId: OpaqueWindowId, _ cm: CancellationMode) async throws -> [String: Json] {
        try await withWindow(windowId, cm) { window, job in
            dumpAxRecursive(window, .window)
        } ?? [:]
    }

    func dumpAppAxInfo(_ cm: CancellationMode) async throws -> [String: Json] {
        try await thread?.runInLoop(cm) { [axApp] job in
            dumpAxRecursive(axApp.threadGuarded, .app)
        } ?? [:]
    }

    @MainActor
    func updateCachedTitle(_ nativeWindowId: UInt32, _ title: String) {
        cachedTitles[nativeWindowId] = title
    }

    @MainActor
    func getAxTitle(_ windowId: OpaqueWindowId, _ cm: CancellationMode) async throws -> String? {
        guard let nativeWindowId = windowIdMapping.forward[windowId] else { return nil }
        if !isUnitTest, let cached = cachedTitles[nativeWindowId], (!cached.isEmpty || nsApp.isHidden) {
            if !nsApp.isHidden {
                _ = withWindowAsync(windowId, .cancellable) { [pid] window, _ in
                    guard let title = window.get(Ax.titleAttr) else { return }
                    Task.startUnstructured { @MainActor in
                        MacApp.allAppsMap[pid]?.cachedTitles[nativeWindowId] = title
                    }
                }
            }
            return cached
        }
        let title = try await withWindow(windowId, cm) { window, job in
            window.get(Ax.titleAttr)
        }
        if let title {
            cachedTitles[nativeWindowId] = title
        }
        return title
    }

    func isMacosNativeFullscreen(_ windowId: OpaqueWindowId, _ cm: CancellationMode) async throws -> Bool? {
        try await withWindow(windowId, cm) { window, job in
            window.get(Ax.isFullscreenAttr)
        }
    }

    func isMacosNativeMinimized(_ windowId: OpaqueWindowId, _ cm: CancellationMode) async throws -> Bool? {
        try await withWindow(windowId, cm) { window, job in
            window.get(Ax.minimizedAttr)
        }
    }

    @MainActor func getWindowLevel(_ windowId: OpaqueWindowId, _ cm: CancellationMode) async throws -> MacOsWindowLevel? {
        guard let nativeWindowId = windowIdMapping.forward[windowId] else { return nil }
        return try await AppBundle::getWindowLevel(forNativeId: nativeWindowId, cm)
    }

    @MainActor static func refreshAllAndGetAliveWindowIds(
        frontmostAppBundleId: String?,
    ) async throws -> [MacApp: [OpaqueWindowId: WindowLifeStatus]] {
        for app in MacApp.allAppsMap.values { // gc dead apps
            try checkCancellation()
            if app.nsApp.isTerminated {
                await app.destroy()
            }
        }
        return try await withThrowingTaskGroup(
            of: (MainActorRef<MacApp>, [OpaqueWindowId: WindowLifeStatus]).self,
            returning: [MacApp: [OpaqueWindowId: WindowLifeStatus]].self,
        ) { group in
            @MainActor func refreshTheApp(_ app: MacApp) {
                group.addTask { @Sendable @MainActor in
                    return (MainActorRef.init(app), try await app.refreshAndGetAliveWindowIds(frontmostAppBundleId: frontmostAppBundleId))
                }
            }
            // Register new apps
            for nsApp in NSWorkspace.shared.runningApplications {
                try checkCancellation()
                if nsApp.activationPolicy == .regular, let app = try await MacApp.getOrRegister(nsApp) {
                    refreshTheApp(app)
                }
            }
            for app in MacApp.allAppsMap.values {
                try checkCancellation()
                // "About this Mac" window, TouchID, and a lot of other utility windows
                // We don't monitor them actively as we do for regular apps, but if a window of one of those utility
                // apps got focused it will end up in allAppsMap
                if app.nsApp.activationPolicy != .regular {
                    refreshTheApp(app)
                }
            }
            var result: [MacApp: [OpaqueWindowId: WindowLifeStatus]] = [:]
            for try await (macAppRef, windowIds) in group {
                result[macAppRef.value] = windowIds
            }
            return result
        }
    }

    @MainActor private func refreshAndGetAliveWindowIds(frontmostAppBundleId: String?) async throws -> [OpaqueWindowId: WindowLifeStatus] {
        if nsApp.isTerminated {
            await destroy()
            return [:]
        }
        if !isUnitTest && hasCompletedInitialWindowRefresh && !needsWindowRefresh {
            switch refreshSessionEvent {
                case .startup:
                    break
                case .globalObserverLeftMouseUp where nsApp.bundleIdentifier == frontmostAppBundleId:
                    break
                default:
                    return cachedAliveWindowIds
            }
        }
        guard let thread else { return [:] }
        let existingTitleIds = Set(cachedTitles.keys)
        let (rawAliveOrInvisible, newTitles) = try await thread
            .runInLoop(.cancellable) { [nsApp, windows, axApp, bgTabsScheduledForPrune] (job) -> ([UInt32: WindowLifeStatus], [UInt32: String]) in
                var aliveOrInvisible: [UInt32: AxWindow] = windows.threadGuarded.filter { !bgTabsScheduledForPrune.contains($0.key) }
                var aliveWindowIds: Set<UInt32> = []
                var newTitles: [UInt32: String] = [:]
                // Second line of defence against lock screen. See the first line of defence: closedWindowsCache
                // Second and third lines of defence are technically needed only to avoid potential flickering
                if frontmostAppBundleId != lockScreenAppBundleId {
                    aliveOrInvisible = try aliveOrInvisible.filter {
                        try job.checkCancellation()
                        return $0.value.ax.containingNativeWindowId() != nil
                    }
                }

                for (id, window) in axApp.threadGuarded.get(Ax.windowsAttr) ?? [] {
                    try job.checkCancellation()
                    if let axWin = try aliveOrInvisible.getOrRegisterAxWindow(windowId: id, window, nsApp, job),
                       !existingTitleIds.contains(id)
                    {
                        newTitles[id] = axWin.ax.get(Ax.titleAttr) ?? ""
                    }
                    aliveWindowIds.insert(id)
                }

                windows.threadGuarded = aliveOrInvisible
                let statuses: [UInt32: WindowLifeStatus] = aliveOrInvisible.keys.associate(with: { it in
                    aliveWindowIds.contains(it) ? .alive : .invisible
                })
                return (statuses, newTitles)
            }
        var aliveOrInvisible = rawAliveOrInvisible
        bgTabsScheduledForPrune = []
        hasCompletedInitialWindowRefresh = true
        needsWindowRefresh = false
        windowsCount = aliveOrInvisible.count
        for (nativeId, title) in newTitles {
            cachedTitles[nativeId] = title
        }
        for nativeId in cachedTitles.keys where aliveOrInvisible[nativeId] == nil {
            cachedTitles.removeValue(forKey: nativeId)
        }

        nonidempotentNativeTabSwapHeuristic(&aliveOrInvisible)

        var aliveOrInvisibleMap: [OpaqueWindowId: WindowLifeStatus] = [:]
        for (id, lifeStatus) in aliveOrInvisible {
            aliveOrInvisibleMap[getOrRegisterOpaqueWindowId(id)] = lifeStatus
        }
        cachedAliveWindowIds = aliveOrInvisibleMap
        for windowId in setFrameJobs.keys {
            if !aliveOrInvisibleMap.keys.contains(windowId) {
                setFrameJobs.removeValue(forKey: windowId)?.cancel()
            }
        }
        return aliveOrInvisibleMap
    }

    private var bgTabsScheduledForPrune: Set<UInt32> = []
    private var lifeStatusesOfLastRefresh: [UInt32: WindowLifeStatus] = [:]
    @MainActor private func nonidempotentNativeTabSwapHeuristic(_ aliveOrInvisible: inout [UInt32: WindowLifeStatus]) {
        let noLongerAlive = lifeStatusesOfLastRefresh.filter { (id, lifeStatus) in lifeStatus == .alive && aliveOrInvisible[id] != .alive }
        let becameAlive = aliveOrInvisible.filter { (id, lifeStatus) in lifeStatus == .alive && lifeStatusesOfLastRefresh[id] != .alive }
        lifeStatusesOfLastRefresh = aliveOrInvisible
        if let backgroundTabId = noLongerAlive.singleOrNil()?.key,
           let frontmostTabId = becameAlive.singleOrNil()?.key
        {
            let tabGroupWindowId = getOrRegisterOpaqueWindowId(backgroundTabId)
            windowIdMapping.put(tabGroupWindowId, frontmostTabId)
            aliveOrInvisible[backgroundTabId] = nil
            bgTabsScheduledForPrune.insert(backgroundTabId)
        }
    }

    private func destroy() async {
        _ = await Task.startUnstructured { @MainActor [pid] in _ = MacApp.allAppsMap.removeValue(forKey: pid) }.result
        for (_, job) in setFrameJobs {
            job.cancel()
        }
        setFrameJobs = [:]
        thread?.runInLoopAsync(job: RunLoopJob(.nonCancellable)) { job in CFRunLoopStop(CFRunLoopGetCurrent()) }
        thread = nil // Disallow all future job submissions
    }

    private func withWindow<T>(
        _ windowId: OpaqueWindowId,
        _ cm: CancellationMode,
        _ body: @Sendable @escaping (AXUIElement, RunLoopJob) throws -> T?,
    ) async throws -> T? {
        guard let nativeWindowId = windowIdMapping.forward[windowId] else { return nil }
        return try await thread?.runInLoop(cm) { [windows] job in
            guard let window = windows.threadGuarded[nativeWindowId] else { return nil }
            return try body(window.ax, job)
        }
    }

    private func withWindowAsync(
        _ windowId: OpaqueWindowId,
        _ cm: CancellationMode,
        onComplete: (@Sendable () -> ())? = nil,
        _ body: @Sendable @escaping (AXUIElement, RunLoopJob) throws -> (),
    ) -> RunLoopJob {
        guard let nativeWindowId = windowIdMapping.forward[windowId], let thread else {
            onComplete?()
            return .cancelled
        }
        return thread.runInLoopAsync(job: RunLoopJob(cm), autoCheckCancelled: false) { [windows] job in
            defer {
                if let onComplete {
                    _ = Thread.current.runInLoopAsync(job: RunLoopJob(.nonCancellable), autoCheckCancelled: false) { _ in
                        onComplete()
                    }
                }
            }
            if job.isCancelled { return }
            guard let window = windows.threadGuarded[nativeWindowId] else { return }
            try? body(window.ax, job)
        }
    }
}

private final class AxWindow {
    let windowId: UInt32
    let ax: AXUIElement
    // periphery:ignore
    private let axSubscriptions: [AxSubscription] // keep subscriptions in memory

    private init(windowId: UInt32, _ ax: AXUIElement, _ axSubscriptions: [AxSubscription]) {
        self.windowId = windowId
        self.ax = ax
        assert(!axSubscriptions.isEmpty)
        self.axSubscriptions = axSubscriptions
    }

    static func new(windowId: UInt32, _ ax: AXUIElement, _ nsApp: NSRunningApplication, _ job: RunLoopJob) throws -> AxWindow? {
        let handlers: HandlerToNotifKeyMapping = unsafe [
            (refreshObs, [kAXUIElementDestroyedNotification, kAXWindowDeminiaturizedNotification, kAXWindowMiniaturizedNotification]),
            (movedObs, [kAXMovedNotification]),
            (resizedObs, [kAXResizedNotification]),
            (titleChangedObs, [kAXTitleChangedNotification]),
        ]
        let subscriptions = try unsafe AxSubscription.bulkSubscribe(nsApp, ax, job, handlers)
        return !subscriptions.isEmpty ? AxWindow(windowId: windowId, ax, subscriptions) : nil
    }
}

private struct ChromeTabMenuSnapshot: Sendable {
    let tabs: [String]
    let checkedIndex: Int?
    let mainWindowId: UInt32?
}

private func findChromeTabSubmenuItems(_ axApp: AXUIElement) -> [AXUIElement]? {
    var menuBarRef: CFTypeRef?
    guard unsafe AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
          let menuBarRef
    else { return nil }
    let menuBar = menuBarRef as! AXUIElement
    var childrenRef: CFTypeRef?
    guard unsafe AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &childrenRef) == .success,
          let topItems = childrenRef as? [AXUIElement]
    else { return nil }
    for item in topItems where item.get(Ax.titleAttr) == "Tab" {
        var subRef: CFTypeRef?
        guard unsafe AXUIElementCopyAttributeValue(item, kAXChildrenAttribute as CFString, &subRef) == .success,
              let subMenu = (subRef as? [AXUIElement])?.first
        else { return nil }
        var subItemsRef: CFTypeRef?
        guard unsafe AXUIElementCopyAttributeValue(subMenu, kAXChildrenAttribute as CFString, &subItemsRef) == .success,
              let subItems = subItemsRef as? [AXUIElement]
        else { return nil }
        return subItems
    }
    return nil
}

private func findMoveTabToNewWindowMenuItem(_ axApp: AXUIElement) -> AXUIElement? {
    guard let subItems = findChromeTabSubmenuItems(axApp) else { return nil }
    return subItems.first(where: { $0.get(Ax.titleAttr) == "Move Tab to New Window" })
}

private func readChromeTabMenuSnapshot(_ axApp: AXUIElement) -> ChromeTabMenuSnapshot? {
    guard let subItems = findChromeTabSubmenuItems(axApp) else { return nil }
    var tabs: [String] = []
    var checkedIndex: Int? = nil
    var afterSearchTabs = false
    for subItem in subItems {
        let title = subItem.get(Ax.titleAttr) ?? ""
        if title == "Search Tabs…" {
            afterSearchTabs = true
            continue
        }
        if afterSearchTabs && !title.isEmpty {
            var markRef: CFTypeRef?
            if unsafe AXUIElementCopyAttributeValue(subItem, kAXMenuItemMarkCharAttribute as CFString, &markRef) == .success,
               (markRef as? String) == "✓"
            {
                checkedIndex = tabs.count
            }
            tabs.append(title)
        }
    }
    let mainWinId = axApp.get(Ax.focusedWindowAttr)?.windowId ?? axApp.get(Ax.windowsAttr)?.first?.windowId
    return ChromeTabMenuSnapshot(tabs: tabs, checkedIndex: checkedIndex, mainWindowId: mainWinId)
}

private func titleChangedObs(_: AXObserver, ax: AXUIElement, _: CFString, _: UnsafeMutableRawPointer?) {
    guard let pid = axTaskLocalAppThreadToken?.pid,
          let windowId = ax.containingNativeWindowId(),
          let title = ax.get(Ax.titleAttr)
    else { return }
    Task.startUnstructured { @MainActor in
        guard let app = MacApp.allAppsMap[pid] else { return }
        app.updateCachedTitle(windowId, title)
        if app.rawAppBundleId == "com.google.Chrome" {
            await app.checkForNewlyOpenedExternalChromeTab(hintWindowId: windowId)
        }
    }
}

extension [UInt32: AxWindow] {
    @discardableResult fileprivate mutating func getOrRegisterAxWindow(
        windowId id: UInt32,
        _ axWindow: AXUIElement,
        _ nsApp: NSRunningApplication,
        _ job: RunLoopJob,
    ) throws -> AxWindow? {
        if let existing = self[id] { return existing }
        // Delay new window detection if mouse is down
        // It helps with apps that allow dragging their tabs out to create new windows
        // https://github.com/nikitabobko/AeroSpace/issues/1001
        if isLeftMouseButtonDown { return nil }

        if let window = try AxWindow.new(windowId: id, axWindow, nsApp, job) {
            self[id] = window
            return window
        } else {
            return nil
        }
    }
}

private func getAxRect(window: AXUIElement, job: RunLoopJob) throws -> Rect? {
    guard let topLeftCorner = window.get(Ax.topLeftCornerAttr) else { return nil }
    try job.checkCancellation()
    guard let size = window.get(Ax.sizeAttr) else { return nil }
    return Rect(topLeftX: topLeftCorner.x, topLeftY: topLeftCorner.y, width: size.width, height: size.height)
}

private func setFrame(_ window: AXUIElement, _ topLeft: CGPoint?, _ size: CGSize?, _ job: RunLoopJob) throws {
    // Set size and then the position. The order is important https://github.com/nikitabobko/AeroSpace/issues/143
    //                                                        https://github.com/nikitabobko/AeroSpace/issues/335
    if let size { window.set(Ax.sizeAttr, size) }
    try job.checkCancellation()
    if let topLeft { window.set(Ax.topLeftCornerAttr, topLeft) } else { return }
    try job.checkCancellation()
    if let size { window.set(Ax.sizeAttr, size) }
}

// Some undocumented magic
// References: https://github.com/koekeishiya/yabai/commit/3fe4c77b001e1a4f613c26f01ea68c0f09327f3a
//             https://github.com/rxhanson/Rectangle/pull/285
private func disableAnimations<T>(app: AXUIElement, _ job: RunLoopJob, _ body: () throws -> T) throws -> T {
    let wasEnabled = app.get(Ax.enhancedUserInterfaceAttr) == true
    if wasEnabled {
        app.set(Ax.enhancedUserInterfaceAttr, false)
    }
    defer {
        if wasEnabled {
            app.set(Ax.enhancedUserInterfaceAttr, true)
        }
    }
    try job.checkCancellation()
    return try body()
}

final class MainActorRef<T>: Sendable {
    @MainActor var value: T
    @MainActor public init(_ value: T) { self.value = value }
}
