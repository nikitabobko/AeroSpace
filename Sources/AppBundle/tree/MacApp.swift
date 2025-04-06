import AppKit
import Common

// Potential alternative implementation
// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md
// (only available since macOS 14)
final class MacApp: AbstractApp {
    /*conforms*/ let pid: Int32
    /*conforms*/ let bundleId: String?
    let nsApp: NSRunningApplication
    let isZoom: Bool
    private let axApp: ThreadGuardedValue<AXUIElement>
    private let appAxSubscriptions: ThreadGuardedValue<[AxSubscription]> // keep subscriptions in memory
    private let windows: ThreadGuardedValue<[UInt32: AxWindow]> = .init([:])
    private var thread: Thread?

    /*conforms*/ var name: String? { nsApp.localizedName }
    /*conforms*/ var execPath: String? { nsApp.executableURL?.path }
    /*conforms*/ var bundlePath: String? { nsApp.bundleURL?.path }

    // todo think if it's possible to integrate this global mutable state to https://github.com/nikitabobko/AeroSpace/issues/1215
    //      and make deinitialization automatic in deinit
    @MainActor static var allAppsMap: [pid_t: MacApp] = [:]
    @MainActor private static var wipPids: Set<pid_t> = []

    private init(_ nsApp: NSRunningApplication, _ axApp: AXUIElement, _ axSubscriptions: [AxSubscription], _ thread: Thread) {
        self.nsApp = nsApp
        self.axApp = .init(axApp)
        self.isZoom = nsApp.bundleIdentifier == "us.zoom.xos"
        self.pid = nsApp.processIdentifier
        self.bundleId = nsApp.bundleIdentifier
        self.appAxSubscriptions = .init(axSubscriptions)
        self.thread = thread
    }

    @MainActor
    @discardableResult
    static func getOrRegister(_ nsApp: NSRunningApplication) async throws -> MacApp? {
        // Don't perceive any of the lock screen windows as real windows
        // Otherwise, false positive ax notifications might trigger that lead to gcWindows
        if nsApp.bundleIdentifier == lockScreenAppBundleId {
            return nil
        }
        let pid = nsApp.processIdentifier
        if let existing = allAppsMap[pid] { return existing }
        try checkCancellation()
        if !wipPids.insert(pid).inserted { return nil } // todo think if it's better to wait or return nil
        defer { wipPids.remove(pid) }
        let app = await withCheckedContinuation { (cont: Continuation<MacApp?>) in
            let thread = Thread {
                $axTaskLocalAppThreadToken.withValue(AxAppThreadToken(pid: pid, idForDebug: nsApp.idForDebug)) {
                    let axApp = AXUIElementCreateApplication(nsApp.processIdentifier)
                    var ticker = IntTicker(value: 0)
                    let handlers: HandlerToNotifKeyMapping = [
                        .init(key: ticker.incAndGet(), value: refreshObs): [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification],
                    ]
                    let subscriptions = AxSubscription.bulkSubscribe(nsApp, axApp, handlers)
                    if !subscriptions.isEmpty {
                        let app = MacApp(nsApp, axApp, subscriptions, Thread.current)
                        cont.resume(returning: app)
                        CFRunLoopRun()
                    } else {
                        cont.resume(returning: nil)
                    }
                }
            }
            thread.name = "app-dedicated-thread \(nsApp.idForDebug)"
            thread.start()
        }
        if let app {
            allAppsMap[pid] = app
            return app
        } else {
            return nil
        }
    }

    @MainActor // todo swift is stupid
    func closeAndUnregisterAxWindow(_ windowId: UInt32) {
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        _ = withWindowAsync(windowId) { [windows] window, job in
            guard let closeButton = window.get(Ax.closeButtonAttr) else { return }
            if AXUIElementPerformAction(closeButton, kAXPressAction as CFString) == .success {
                windows.threadGuarded.removeValue(forKey: windowId)
            }
        }
    }

    @MainActor // todo swift is stupid
    func getAxSize(_ windowId: UInt32) async throws -> CGSize? {
        try await withWindow(windowId) { window, job in
            window.get(Ax.sizeAttr)
        }
    }

    // todo merge together with detectNewWindows
    @MainActor // todo swift is stupid
    func getFocusedWindow() async throws -> Window? {
        let windowId = try await thread?.runInLoop { [nsApp, axApp, windows] job in
            axApp.threadGuarded.get(Ax.focusedWindowAttr).flatMap { windows.threadGuarded.getOrRegisterAxWindow($0, nsApp) }?.windowId
        }
        guard let windowId else { return nil }
        return try await MacWindow.getOrRegister(windowId: windowId, macApp: self)
    }

    @MainActor private static var focusJob: RunLoopJob? = nil
    @MainActor func nativeFocus(_ windowId: UInt32) {
        MacApp.focusJob?.cancel()
        MacApp.focusJob = withWindowAsync(windowId) { [nsApp] window, job in
            // Raise firstly to make sure that by the time we activate the app, the window would be already on top
            window.set(Ax.isMainAttr, true)
            _ = window.raise()
            nsApp.activate(options: .activateIgnoringOtherApps)
        }
    }

    private var setFrameJobs: [UInt32: RunLoopJob] = [:]
    func setAxFrame(_ windowId: UInt32, _ topLeft: CGPoint?, _ size: CGSize?) {
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        setFrameJobs[windowId] = withWindowAsync(windowId) { [axApp] window, job in
            disableAnimations(app: axApp.threadGuarded) {
                setFrame(window, topLeft, size)
            }
        }
    }

    @MainActor // todo swift is stupid
    func setAxFrameBlocking(_ windowId: UInt32, _ topLeft: CGPoint?, _ size: CGSize?) async throws {
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        setFrameJobs[windowId] = nil
        try await withWindow(windowId) { [axApp] window, job in
            disableAnimations(app: axApp.threadGuarded) {
                setFrame(window, topLeft, size)
            }
        }
    }

    func setAxSize(_ windowId: UInt32, _ size: CGSize) {
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        setFrameJobs[windowId] = withWindowAsync(windowId) { [axApp] window, job in
            disableAnimations(app: axApp.threadGuarded) {
                _ = window.set(Ax.sizeAttr, size)
            }
        }
    }

    func setAxTopLeftCorner(_ windowId: UInt32, _ point: CGPoint) {
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        setFrameJobs[windowId] = withWindowAsync(windowId) { [axApp] window, job in
            disableAnimations(app: axApp.threadGuarded) {
                _ = window.set(Ax.topLeftCornerAttr, point)
            }
        }
    }

    @MainActor // todo swift is stupid
    func getAxWindowsCount() async throws -> Int? {
        try await thread?.runInLoop { [axApp] job in
            axApp.threadGuarded.get(Ax.windowsAttr)?.count
        }
    }

    @MainActor // todo swift is stupid
    func getAxTopLeftCorner(_ windowId: UInt32) async throws -> CGPoint? {
        try await withWindow(windowId) { window, job in
            window.get(Ax.topLeftCornerAttr)
        }
    }

    @MainActor // todo swift is stupid
    func getAxRect(_ windowId: UInt32) async throws -> Rect? {
        try await withWindow(windowId) { window, job in
            guard let topLeftCorner = window.get(Ax.topLeftCornerAttr) else { return nil }
            guard let size = window.get(Ax.sizeAttr) else { return nil }
            return Rect(topLeftX: topLeftCorner.x, topLeftY: topLeftCorner.y, width: size.width, height: size.height)
        }
    }

    @MainActor // todo swift is stupid
    func isWindowHeuristic(_ windowId: UInt32) async throws -> Bool {
        try await withWindow(windowId) { [axApp, bundleId] window, job in
            window.isWindowHeuristic(axApp: axApp.threadGuarded, appBundleId: bundleId)
        } == true
    }

    @MainActor // todo swift is stupid
    func isDialogHeuristic(_ windowId: UInt32) async throws -> Bool {
        try await withWindow(windowId) { [nsApp] window, job in
            window.isDialogHeuristic(nsApp)
        } == true
    }

    func setNativeFullscreen(_ windowId: UInt32, _ value: Bool) {
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        setFrameJobs[windowId] = withWindowAsync(windowId) { window, job in
            window.set(Ax.isFullscreenAttr, value)
        }
    }

    func setNativeMinimized(_ windowId: UInt32, _ value: Bool) {
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        setFrameJobs[windowId] = withWindowAsync(windowId) { window, job in
            window.set(Ax.minimizedAttr, value)
        }
    }

    @MainActor // todo swift is stupid
    func dumpWindowAxInfo(windowId: UInt32, _ prefix: String) async throws -> String {
        try await withWindow(windowId) { window, job in
            dumpAx(window, prefix, .window)
        } ?? ""
    }

    @MainActor // todo swift is stupid
    func getAxTitle(_ windowId: UInt32) async throws -> String? {
        try await withWindow(windowId) { window, job in
            window.get(Ax.titleAttr)
        }
    }

    @MainActor // todo swift is stupid
    func isMacosNativeFullscreen(_ windowId: UInt32) async throws -> Bool? {
        try await withWindow(windowId) { window, job in
            window.get(Ax.isFullscreenAttr)
        }
    }

    @MainActor // todo swift is stupid
    func isMacosNativeMinimized(_ windowId: UInt32) async throws -> Bool? {
        try await withWindow(windowId) { window, job in
            window.get(Ax.minimizedAttr)
        }
    }

    @MainActor // todo swift is stupid
    func dumpAppAxInfo(_ prefix: String) async throws -> String {
        try await thread?.runInLoop { [axApp] job in
            dumpAx(axApp.threadGuarded, prefix, .app)
        } ?? ""
    }

    @MainActor
    static func refreshAllAndGetAliveWindowIds(frontmostAppBundleId: String?) async throws -> [MacApp: [UInt32]] {
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Register new apps
            for nsApp in NSWorkspace.shared.runningApplications where nsApp.activationPolicy == .regular {
                try group.addTaskOrCancelAll { @Sendable @MainActor in
                    _ = try await getOrRegister(nsApp)
                }
            }
            try await group.waitForAll()
        }
        return try await withThrowingTaskGroup(of: (pid_t, [UInt32]).self, returning: [MacApp: [UInt32]].self) { group in
            // gc dead apps. refresh underlying windows
            for (_, app) in MacApp.allAppsMap {
                try group.addTaskOrCancelAll { @Sendable @MainActor in
                    (app.pid, try await app.refreshAndGetAliveWindowIds(frontmostAppBundleId: frontmostAppBundleId))
                }
            }
            var result: [MacApp: [UInt32]] = [:]
            for try await (pid, windowIds) in group {
                if let app = allAppsMap[pid] {
                    result[app] = windowIds
                }
            }
            return result
        }
    }

    @MainActor
    private func refreshAndGetAliveWindowIds(frontmostAppBundleId: String?) async throws -> [UInt32] {
        if nsApp.isTerminated {
            MacApp.allAppsMap.removeValue(forKey: pid)
            thread?.runInLoopAsync { [windows, appAxSubscriptions, axApp] job in
                axApp.destroy()
                appAxSubscriptions.destroy()
                windows.destroy()
                CFRunLoopStop(CFRunLoopGetCurrent())
            }
            thread = nil // Disallow all future job submissions
            return []
        }
        guard let thread else { return [] }
        return try await thread.runInLoop { [nsApp, windows, axApp] (job) -> [UInt32] in
            var result: [UInt32: AxWindow] = windows.threadGuarded
            // Second line of defence against lock screen. See the first line of defence: closedWindowsCache
            // Second and third lines of defence are technically needed only to avoid potential flickering
            if frontmostAppBundleId != lockScreenAppBundleId {
                result = try result.filter {
                    try job.checkCancellation()
                    return $0.value.ax.containingWindowId(signpostEvent: nsApp.idForDebug) != nil
                }
            }

            for window in axApp.threadGuarded.get(Ax.windowsAttr) ?? [] {
                try job.checkCancellation()
                result.getOrRegisterAxWindow(window, nsApp)
            }

            windows.threadGuarded = result
            return Array(result.keys)
        }
    }

    @MainActor // todo swift is stupid
    private func withWindow<T>(_ windowId: UInt32, _ body: @Sendable @escaping (AXUIElement, RunLoopJob) throws -> T?) async throws -> T? {
        try await thread?.runInLoop { [windows] job in
            guard let window = windows.threadGuarded[windowId] else { return nil }
            return try body(window.ax, job)
        }
    }

    private func withWindowAsync(_ windowId: UInt32, _ body: @Sendable @escaping (AXUIElement, RunLoopJob) -> ()) -> RunLoopJob {
        thread?.runInLoopAsync { [windows] job in
            guard let window = windows.threadGuarded[windowId] else { return }
            body(window.ax, job)
        } ?? .cancelled
    }
}

private class AxWindow {
    let windowId: UInt32
    let ax: AXUIElement
    private let axSubscriptions: [AxSubscription] // keep subscriptions in memory

    private init(windowId: UInt32, _ ax: AXUIElement, _ axSubscriptions: [AxSubscription]) {
        self.windowId = windowId
        self.ax = ax
        self.axSubscriptions = axSubscriptions
    }

    static func new(windowId: UInt32, _ ax: AXUIElement, _ nsApp: NSRunningApplication) -> AxWindow? {
        guard let id = ax.containingWindowId() else { return nil }
        var ticker = IntTicker(value: 0)
        let handlers: HandlerToNotifKeyMapping = [
            .init(key: ticker.incAndGet(), value: refreshObs): [kAXUIElementDestroyedNotification, kAXWindowDeminiaturizedNotification, kAXWindowMiniaturizedNotification],
            .init(key: ticker.incAndGet(), value: movedObs): [kAXMovedNotification],
            .init(key: ticker.incAndGet(), value: resizedObs): [kAXResizedNotification],
        ]
        let subscriptions = AxSubscription.bulkSubscribe(nsApp, ax, handlers)
        return !subscriptions.isEmpty ? AxWindow(windowId: id, ax, subscriptions) : nil
    }
}

extension [UInt32: AxWindow] {
    @discardableResult
    fileprivate mutating func getOrRegisterAxWindow(_ axWindow: AXUIElement, _ nsApp: NSRunningApplication) -> AxWindow? {
        guard let id = axWindow.containingWindowId() else { return nil }
        if let existing = self[id] {
            return existing
        } else {
            // Delay new window detection if mouse is down
            // It helps with apps that allow dragging their tabs out to create new windows
            // https://github.com/nikitabobko/AeroSpace/issues/1001
            if isLeftMouseButtonDown { return nil }

            if let window = AxWindow.new(windowId: id, axWindow, nsApp) {
                self[id] = window
                return window
            } else {
                return nil
            }
        }
    }
}

private func setFrame(_ window: AXUIElement, _ topLeft: CGPoint?, _ size: CGSize?) {
    // Set size and then the position. The order is important https://github.com/nikitabobko/AeroSpace/issues/143
    //                                                        https://github.com/nikitabobko/AeroSpace/issues/335
    if let size { window.set(Ax.sizeAttr, size) }
    if let topLeft { window.set(Ax.topLeftCornerAttr, topLeft) } else { return }
    if let size { window.set(Ax.sizeAttr, size) }
}

// Some undocumented magic
// References: https://github.com/koekeishiya/yabai/commit/3fe4c77b001e1a4f613c26f01ea68c0f09327f3a
//             https://github.com/rxhanson/Rectangle/pull/285
private func disableAnimations<T>(app: AXUIElement, _ body: () -> T) -> T {
    let wasEnabled = app.get(Ax.enhancedUserInterfaceAttr) == true
    if wasEnabled {
        app.set(Ax.enhancedUserInterfaceAttr, false)
    }
    defer {
        if wasEnabled {
            app.set(Ax.enhancedUserInterfaceAttr, true)
        }
    }
    return body()
}

public typealias Continuation<T> = CheckedContinuation<T, Never>
