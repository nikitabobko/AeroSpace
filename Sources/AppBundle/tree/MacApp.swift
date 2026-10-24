import AppKit
import Common

// Potential alternative implementation
// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md
// (only available since macOS 14)
final class MacApp: AbstractApp {
    /*conforms*/ let pid: Int32
    /*conforms*/ let rawAppBundleId: String?
    let appId: KnownBundleId?
    let nsApp: NSRunningApplication
    private let axApp: ThreadGuardedValue<AXUIElement>
    private let appAxSubscriptions: ThreadGuardedValue<[AxSubscription]> // keep subscriptions in memory
    private let windows: ThreadGuardedValue<[UInt32: AxWindow]> = .init([:])
    private var windowsCount = 0
    var lastNativeFocusedWindowId: UInt32? = nil
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
    @MainActor private var cachedAliveWindowIds: [UInt32] = []
    @MainActor private var hasCompletedInitialWindowRefresh: Bool = false
    @MainActor var needsWindowRefresh: Bool = false
    @MainActor private var cachedTitles: [UInt32: String] = [:]
    @MainActor private var lastBackgroundMainWindowId: UInt32? = nil
    private var thread: Thread?
    private var setFrameJobs: [UInt32: RunLoopJob] = [:]
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

    @MainActor
    @discardableResult
    static func getOrRegister(_ nsApp: NSRunningApplication) async throws -> MacApp? {
        // Don't perceive any of the lock screen windows as real windows
        // Otherwise, false positive ax notifications might trigger that lead to gcWindows
        if nsApp.bundleIdentifier == lockScreenAppBundleId { return nil }
        let pid = nsApp.processIdentifier
        // AX requests crash if you send them to yourself
        if pid == myPid { return nil }

        if let existing = allAppsMap[pid] { return existing }
        try checkCancellation()
        if let wip = wipPids[pid] {
            try await wip.await()
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
                    (refreshObs, [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification]),
                ]
                let job = RunLoopJob(.cancellable)
                let subscriptions = (try? unsafe AxSubscription.bulkSubscribe(nsApp, axApp, job, handlers)) ?? []
                let isGood = !subscriptions.isEmpty
                let app = isGood ? MacApp(nsApp, axApp, subscriptions, Thread.current) : nil

                let appAxSubscriptionsThreadGuarded = app?.appAxSubscriptions
                let windowsThreadGuarded = app?.windows
                let axAppThreadGuarded = app?.axApp

                Task.startUnstructured { @MainActor in
                    if let app, isStartup && nsApp.isHidden {
                        app.isHiddenByAeroSpace = true
                    }
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

        try await wip.await()
        return allAppsMap[pid]
    }

    func closeAndUnregisterAxWindow(_ windowId: UInt32) {
        if serverArgs.isReadOnly { return }
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        _ = withWindowAsync(windowId, .cancellable) { [windows] window, job in
            guard let closeButton = window.get(Ax.closeButtonAttr) else { return }
            if AXUIElementPerformAction(closeButton.cast, kAXPressAction as CFString) == .success {
                windows.threadGuarded.removeValue(forKey: windowId)
            }
        }
    }

    func getAxSize(_ windowId: UInt32, _ cm: CancellationMode) async throws -> CGSize? {
        try await withWindow(windowId, cm) { window, job in
            window.get(Ax.sizeAttr)
        }
    }

    // todo merge together with detectNewWindows
    func getFocusedWindow(_ cm: CancellationMode) async throws -> Window? {
        let windowId = try await thread?.runInLoop(cm) { [nsApp, axApp, windows] job in
            try axApp.threadGuarded.get(Ax.focusedWindowAttr)
                .flatMap { try windows.threadGuarded.getOrRegisterAxWindow(windowId: $0.windowId, $0.ax.cast, nsApp, job) }?
                .windowId
        }
        guard let windowId else { return nil }
        return try await MacWindow.getOrRegister(windowId: windowId, macApp: self)
    }

    @MainActor func nativeFocus(_ windowId: UInt32) {
        if serverArgs.isReadOnly { return }
        unhideIfHiddenByAeroSpace(forceIfHidden: true)
        lastBackgroundMainWindowId = windowId
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
                    if app.inFlightFocusJobsCount == 0 && NSWorkspace.shared.frontmostApplication?.processIdentifier == pid {
                        onAppActivatedInWorkspace(pid)
                    }
                }
            }
        }) { [nsApp] window, job in
            // Raise firstly to make sure that by the time we activate the app, the window would be already on top
            window.set(Ax.isMainAttr, true)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            nsApp.activate(options: .activateIgnoringOtherApps)
        }
    }

    @MainActor
    func hasStandardChromeTitle(_ windowId: UInt32) -> Bool {
        cachedTitles[windowId]?.contains("Google Chrome") == true
    }

    @MainActor
    func setMainWindowWithoutActivating(_ windowId: UInt32) {
        if isUnitTest || serverArgs.isReadOnly { return }
        guard lastBackgroundMainWindowId != windowId else { return }
        lastBackgroundMainWindowId = windowId
        lastNativeFocusedWindowId = windowId
        inFlightFocusJobsCount += 1
        let pid = self.pid
        _ = withWindowAsync(windowId, .cancellable, onComplete: {
            Task.startUnstructured { @MainActor in
                if let app = MacApp.allAppsMap[pid] {
                    app.inFlightFocusJobsCount = max(0, app.inFlightFocusJobsCount - 1)
                }
            }
        }) { window, _ in
            window.set(Ax.isMainAttr, true)
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
        if focus.windowOrNil?.app.pid == pid || stickyClosedAppPidOnCurrentWorkspace == pid || (focus.windowOrNil == nil && nsApp.isActive) { return false }
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

    func setAxFrame(_ windowId: UInt32, _ topLeft: CGPoint?, _ size: CGSize?) {
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

    func setAxFrameForTermination(_ windowId: UInt32, _ topLeft: CGPoint?, _ size: CGSize?) {
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

    func getAxRect(_ windowId: UInt32, _ cm: CancellationMode) async throws -> Rect? {
        try await withWindow(windowId, cm) { window, job in
            try AppBundle.getAxRect(window: window, job: job)
        }
    }

    func getAxRectForTermination(_ windowId: UInt32) -> Rect? {
        let future = CompletableFuture<Rect?>()
        let job = withWindowAsync(windowId, .nonCancellable) { window, job in
            future.complete(try AppBundle.getAxRect(window: window, job: job))
        }
        return switch job.isCancelled {
            case true: nil
            case false: future.blockingGet()
        }
    }

    func isWindowHeuristic(_ windowId: UInt32, _ windowLevel: MacOsWindowLevel?, _ cm: CancellationMode) async throws -> Bool {
        return try await withWindow(windowId, cm) { [nsApp, axApp, appId] window, job in
            window.isWindowHeuristic(axApp: axApp.threadGuarded, appId, nsApp.activationPolicy, windowLevel)
        } == true
    }

    func getAxUiElementWindowType(_ windowId: UInt32, _ windowLevel: MacOsWindowLevel?, _ cm: CancellationMode) async throws -> AxUiElementWindowType {
        return try await withWindow(windowId, cm) { [nsApp, axApp, appId] window, job in
            window.getWindowType(axApp: axApp.threadGuarded, appId, nsApp.activationPolicy, windowLevel)
        } ?? .window
    }

    func isDialogHeuristic(_ windowId: UInt32, _ windowLevel: MacOsWindowLevel?, _ cm: CancellationMode) async throws -> Bool {
        try await withWindow(windowId, cm) { [appId] window, job in
            window.isDialogHeuristic(appId, windowLevel)
        } == true
    }

    func setNativeFullscreen(_ windowId: UInt32, _ value: Bool) {
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        setFrameJobs[windowId] = withWindowAsync(windowId, .cancellable) { window, job in
            window.set(Ax.isFullscreenAttr, value)
        }
    }

    func setNativeMinimized(_ windowId: UInt32, _ value: Bool) {
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        setFrameJobs[windowId] = withWindowAsync(windowId, .cancellable) { window, job in
            window.set(Ax.minimizedAttr, value)
        }
    }

    func dumpWindowAxInfo(windowId: UInt32, _ cm: CancellationMode) async throws -> [String: Json] {
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
    func updateCachedTitle(_ windowId: UInt32, _ title: String) {
        cachedTitles[windowId] = title
    }

    @MainActor
    func getAxTitle(_ windowId: UInt32, _ cm: CancellationMode) async throws -> String? {
        if !isUnitTest, let cached = cachedTitles[windowId], (!cached.isEmpty || nsApp.isHidden) {
            if !nsApp.isHidden {
                _ = withWindowAsync(windowId, .cancellable) { [pid] window, _ in
                    guard let title = window.get(Ax.titleAttr) else { return }
                    Task.startUnstructured { @MainActor in
                        MacApp.allAppsMap[pid]?.cachedTitles[windowId] = title
                    }
                }
            }
            return cached
        }
        let title = try await withWindow(windowId, cm) { window, job in
            window.get(Ax.titleAttr)
        }
        if let title {
            cachedTitles[windowId] = title
        }
        return title
    }

    func isMacosNativeFullscreen(_ windowId: UInt32, _ cm: CancellationMode) async throws -> Bool? {
        try await withWindow(windowId, cm) { window, job in
            window.get(Ax.isFullscreenAttr)
        }
    }

    func isMacosNativeMinimized(_ windowId: UInt32, _ cm: CancellationMode) async throws -> Bool? {
        try await withWindow(windowId, cm) { window, job in
            window.get(Ax.minimizedAttr)
        }
    }

    @MainActor
    static func refreshAllAndGetAliveWindowIds(frontmostAppBundleId: String?) async throws -> [MacApp: [UInt32]] {
        for (_, app) in MacApp.allAppsMap { // gc dead apps
            try checkCancellation()
            if app.nsApp.isTerminated {
                await app.destroy()
            }
        }
        return try await withThrowingTaskGroup(of: (pid_t, [UInt32]).self, returning: [MacApp: [UInt32]].self) { group in
            func refreshTheApp(_ nsApp: NSRunningApplication) {
                group.addTask { @Sendable @MainActor in
                    guard let app = try await MacApp.getOrRegister(nsApp) else { return (nsApp.processIdentifier, []) }
                    return (nsApp.processIdentifier, try await app.refreshAndGetAliveWindowIds(frontmostAppBundleId: frontmostAppBundleId))
                }
            }
            // Register new apps
            for nsApp in NSWorkspace.shared.runningApplications {
                try checkCancellation()
                if nsApp.activationPolicy == .regular {
                    refreshTheApp(nsApp)
                }
            }
            for (_, app) in MacApp.allAppsMap {
                try checkCancellation()
                // "About this Mac" window, TouchID, and a lot of other utility windows
                // We don't monitor them actively as we do for regular apps, but if a window of one of those utility
                // apps got focused it will end up in allAppsMap
                if app.nsApp.activationPolicy != .regular {
                    refreshTheApp(app.nsApp)
                }
            }
            var result: [MacApp: [UInt32]] = [:]
            for try await (pid, windowIds) in group {
                if let app = MacApp.allAppsMap[pid] {
                    result[app] = windowIds
                }
            }
            return result
        }
    }

    @MainActor
    private func refreshAndGetAliveWindowIds(frontmostAppBundleId: String?) async throws -> [UInt32] {
        if nsApp.isTerminated {
            await destroy()
            return []
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
        guard let thread else { return [] }
        let existingTitleIds = Set(cachedTitles.keys)
        let (alive, dead, newTitles) = try await thread.runInLoop(.cancellable) { [nsApp, windows, axApp] (job) -> ([UInt32], [UInt32], [UInt32: String]) in
            var alive: [UInt32: AxWindow] = windows.threadGuarded
            var dead = [UInt32: AxWindow]()
            var newTitles: [UInt32: String] = [:]
            // Second line of defence against lock screen. See the first line of defence: closedWindowsCache
            // Second and third lines of defence are technically needed only to avoid potential flickering
            if frontmostAppBundleId != lockScreenAppBundleId {
                (alive, dead) = try alive.partition {
                    try job.checkCancellation()
                    return $0.value.ax.containingWindowId() != nil
                }
            }

            for (id, window) in axApp.threadGuarded.get(Ax.windowsAttr) ?? [] {
                try job.checkCancellation()
                if let axWin = try alive.getOrRegisterAxWindow(windowId: id, window, nsApp, job),
                   !existingTitleIds.contains(id)
                {
                    newTitles[id] = axWin.ax.get(Ax.titleAttr) ?? ""
                }
            }

            windows.threadGuarded = alive
            return (Array(alive.keys), Array(dead.keys), newTitles)
        }
        hasCompletedInitialWindowRefresh = true
        needsWindowRefresh = false
        windowsCount = alive.count
        cachedAliveWindowIds = alive
        for (windowId, title) in newTitles {
            cachedTitles[windowId] = title
        }
        for windowId in dead {
            setFrameJobs.removeValue(forKey: windowId)?.cancel()
            cachedTitles.removeValue(forKey: windowId)
        }
        return alive
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
        _ windowId: UInt32,
        _ cm: CancellationMode,
        _ body: @Sendable @escaping (AXUIElement, RunLoopJob) throws -> T?,
    ) async throws -> T? {
        try await thread?.runInLoop(cm) { [windows] job in
            guard let window = windows.threadGuarded[windowId] else { return nil }
            return try body(window.ax, job)
        }
    }

    private func withWindowAsync(
        _ windowId: UInt32,
        _ cm: CancellationMode,
        onComplete: (@Sendable () -> ())? = nil,
        _ body: @Sendable @escaping (AXUIElement, RunLoopJob) throws -> (),
    ) -> RunLoopJob {
        guard let thread else {
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
            guard let window = windows.threadGuarded[windowId] else { return }
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
        ]
        let subscriptions = try unsafe AxSubscription.bulkSubscribe(nsApp, ax, job, handlers)
        return !subscriptions.isEmpty ? AxWindow(windowId: windowId, ax, subscriptions) : nil
    }
}

private func titleChangedObs(_: AXObserver, ax: AXUIElement, _: CFString, _: UnsafeMutableRawPointer?) {
    guard let pid = axTaskLocalAppThreadToken?.pid,
          let windowId = ax.containingWindowId(),
          let title = ax.get(Ax.titleAttr)
    else { return }
    Task.startUnstructured { @MainActor in
        MacApp.allAppsMap[pid]?.updateCachedTitle(windowId, title)
    }
}

extension [UInt32: AxWindow] {
    @discardableResult
    fileprivate mutating func getOrRegisterAxWindow(windowId id: UInt32, _ axWindow: AXUIElement, _ nsApp: NSRunningApplication, _ job: RunLoopJob) throws -> AxWindow? {
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
