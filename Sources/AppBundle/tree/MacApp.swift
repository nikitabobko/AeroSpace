import AppKit
import Common

// Potential alternative implementation
// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md
// (only available since macOS 14)
final class MacApp: AbstractApp {
    /*conforms*/ let pid: Int32
    /*conforms*/ let bundleId: String?
    let nsApp: NSRunningApplication
    private let axApp: ThreadGuardedValue<AXUIElement>
    let isZoom: Bool
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
    static func get(_ nsApp: NSRunningApplication) async throws -> MacApp? {
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
                $axAppThreadToken.withValue(AxAppThreadToken(pid: pid, idForDebug: nsApp.idForDebug)) {
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
        withWindowAsync(windowId) { [windows] window, job in
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
        let windowId = try await getThreadOrCancel().runInLoop { [nsApp, axApp, windows] job in
            axApp.threadGuarded.get(Ax.focusedWindowAttr).flatMap { windows.threadGuarded.getOrRegisterAxWindow($0, nsApp) }?.windowId
        }
        guard let windowId else { return nil }
        return try await MacWindow.getOrRegister(windowId: windowId, macApp: self)
    }

    func nativeFocus(_ windowId: UInt32) {
        withWindowAsync(windowId) { [nsApp] window, job in
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
        try await getThreadOrCancel().runInLoop { [axApp] job in
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
        withWindowAsync(windowId) { window, job in
            window.set(Ax.isFullscreenAttr, value)
        }
    }

    func setNativeMinimized(_ windowId: UInt32, _ value: Bool) {
        setFrameJobs.removeValue(forKey: windowId)?.cancel()
        withWindowAsync(windowId) { window, job in
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
        try await getThreadOrCancel().runInLoop { [axApp] job in
            dumpAx(axApp.threadGuarded, prefix, .app)
        }
    }

    @MainActor func detectNewWindowsAndGetIds() async throws -> [UInt32] {
        try await thread?.runInLoop { [axApp, windows, nsApp] job in
            guard let newWindows = axApp.threadGuarded.get(Ax.windowsAttr, signpostEvent: nsApp.idForDebug) else { return Array(windows.threadGuarded.keys) }
            var result: [UInt32] = []
            for window in newWindows {
                try job.checkCancellation()
                if let windowId = windows.threadGuarded.getOrRegisterAxWindow(window, nsApp)?.windowId {
                    result.append(windowId)
                }
            }
            return result
        } ?? []
    }

    @MainActor
    func gcDeadWindowsAndGetAliveIds(frontmostAppBundleId: String?) async throws -> Set<UInt32> {
        try await thread?.runInLoop { [nsApp, windows] (job) -> Set<UInt32> in
            // Second line of defence against lock screen. See the first line of defence: closedWindowsCache
            // Second and third lines of defence are technically needed only to avoid potential flickering
            let _windows: [UInt32: AxWindow] = windows.threadGuarded
            if frontmostAppBundleId == lockScreenAppBundleId { return Set(_windows.keys) }
            let toKeepAlive: [UInt32: AxWindow] = try _windows.filter {
                try job.checkCancellation()
                return $0.value.ax.containingWindowId(signpostEvent: nsApp.idForDebug) != nil
            }
            windows.threadGuarded = toKeepAlive
            return Set(toKeepAlive.keys)
        } ?? []
    }

    @MainActor
    func unregisterWindow(_ windowId: UInt32) {
        thread?.runInLoopAsync { [windows] job in
            windows.threadGuarded.removeValue(forKey: windowId)
        }
    }

    @MainActor
    static func gcTerminatedApps() {
        for app in allAppsMap.values where app.nsApp.isTerminated {
            app.destroy(skipClosedWindowsCache: true)
        }
    }

    @MainActor
    func destroy(skipClosedWindowsCache: Bool) {
        MacApp.allAppsMap.removeValue(forKey: nsApp.processIdentifier)
        for (_, window) in MacWindow.allWindowsMap where window.app.pid == self.pid {
            window.garbageCollect(skipClosedWindowsCache: skipClosedWindowsCache, unregisterAxWindow: false)
        }
        thread?.runInLoopAsync { [windows, appAxSubscriptions, axApp] job in
            axApp.destroy()
            appAxSubscriptions.destroy()
            windows.destroy()
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
        thread = nil // Disallow all future job submissions
    }

    private func getThreadOrCancel() throws -> Thread { // todo convert untyped throws to throws across the whole app
        if let thread { return thread }
        throw CancellationError()
    }

    @MainActor // todo swift is stupid
    private func withWindow<T>(_ windowId: UInt32, _ body: @Sendable @escaping (AXUIElement, RunLoopJob) throws -> T?) async throws -> T? {
        try await getThreadOrCancel().runInLoop { [windows] job in
            guard let window = windows.threadGuarded[windowId] else { return nil }
            return try body(window.ax, job)
        }
    }

    @discardableResult
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

@TaskLocal
var axAppThreadToken: AxAppThreadToken? = nil

struct AxAppThreadToken: Sendable, Equatable {
    let pid: pid_t
    let idForDebug: String
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.pid == rhs.pid }
}

public final class ThreadGuardedValue<Value>: Sendable {
    private nonisolated(unsafe) var _threadGuarded: Value?
    private let threadToken: AxAppThreadToken = axAppThreadToken ?? dieT("axAppThreadToken is not initialized")
    public init(_ value: Value) { self._threadGuarded = value }
    var threadGuarded: Value {
        get {
            check(axAppThreadToken == threadToken)
            return _threadGuarded ?? dieT("Value is already destroyed")
        }
        set(newValue) {
            check(axAppThreadToken == threadToken)
            _threadGuarded = newValue
        }
    }
    func destroy() {
        check(axAppThreadToken == threadToken)
        _threadGuarded = nil
    }
    deinit {
        check(_threadGuarded == nil, "The Value must be explicitly destroyed on the appropriate thread before deinit")
    }
}

public final class MutableUnsafeSendable<T>: Sendable {
    nonisolated(unsafe) var unsafe: T
    public init(_ value: T) { self.unsafe = value }
}

public final class UnsafeSendable<T>: Sendable {
    nonisolated(unsafe) let unsafe: T
    public init(_ value: T) { self.unsafe = value }
}

public typealias Continuation<T> = CheckedContinuation<T, Never>

extension NSRunningApplication {
    func isFirefox() -> Bool {
        ["org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly"].contains(bundleIdentifier ?? "")
    }

    var idForDebug: String {
        "PID: \(processIdentifier) ID: \(bundleIdentifier ?? executableURL?.description ?? "")"
    }

    @MainActor
    var macApp: MacApp? { get async throws { try await MacApp.get(self) } }
}
