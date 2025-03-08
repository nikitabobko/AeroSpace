import AppKit
import Common

// Potential alternative implementation
// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md
// (only available since macOS 14)
final class MacApp: AbstractApp {
    /*conforms*/ let pid: Int32
    /*conforms*/ let id: String? // todo rename to bundleId
    let nsApp: NSRunningApplication
    private let axApp: UnsafeSendable<AXUIElement>
    let isZoom: Bool
    private let appAxObservers: UnsafeSendable<[AxObserverWrapper]> // keep observers in memory
    private let windows: MutableUnsafeSendable<[UInt32: AxWindow]> = .init([:])
    private var thread: Thread?

    /*conforms*/ var name: String? { nsApp.localizedName }
    /*conforms*/ var execPath: String? { nsApp.executableURL?.path }
    /*conforms*/ var bundlePath: String? { nsApp.bundleURL?.path }

    // todo think if it's possible to integrate this global mutable state to https://github.com/nikitabobko/AeroSpace/issues/1215
    //      and make deinitialization automatic in deinit
    @MainActor static var allAppsMap: [pid_t: MacApp] = [:]
    @MainActor private static var wipPids: Set<pid_t> = []

    private init(_ nsApp: NSRunningApplication, _ axApp: AXUIElement, _ axObservers: [AxObserverWrapper], _ thread: Thread) {
        self.pid = nsApp.processIdentifier
        self.id = nsApp.bundleIdentifier
        self.nsApp = nsApp
        self.axApp = .init(axApp)
        self.appAxObservers = .init(axObservers)
        self.thread = thread
        self.isZoom = nsApp.bundleIdentifier == "us.zoom.xos"
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
                let axApp = AXUIElementCreateApplication(nsApp.processIdentifier)
                var observers: [AxObserverWrapper] = []
                if observe(refreshObs, axApp, nsApp, kAXWindowCreatedNotification, &observers) &&
                    observe(refreshObs, axApp, nsApp, kAXFocusedWindowChangedNotification, &observers)
                {
                    let app = MacApp(nsApp, axApp, observers, Thread.current)
                    cont.resume(returning: app)
                } else {
                    unsubscribeAxObservers(observers)
                    cont.resume(returning: nil)
                }
                CFRunLoopRun()
            }
            thread.name = "app-dedicated-thread pid=\(pid) \(nsApp.bundleIdentifier ?? nsApp.executableURL?.description ?? "")"
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
    func closeWindowInBg(_ windowId: UInt32) {
        withWindowInBg(windowId) { window, job in
            guard let closeButton = window.get(Ax.closeButtonAttr) else { return }
            AXUIElementPerformAction(closeButton, kAXPressAction as CFString)
        }
    }

    @MainActor // todo swift is stupid
    func getSize(_ windowId: UInt32) async throws -> CGSize? {
        try await withWindow(windowId) { window, job in
            window.get(Ax.sizeAttr)
        }
    }

    // todo merge together with detectNewWindows
    @MainActor // todo swift is stupid
    func getFocusedWindow() async throws -> Window? {
        let windowId = try await getThreadOrCancel().runInLoop { [nsApp, axApp, windows] job in
            axApp.unsafe.get(Ax.focusedWindowAttr).flatMap { getOrRegisterAxWindow($0, windows.unsafe, nsApp) }?.windowId
        }
        guard let windowId else { return nil }
        return try await MacWindow.getOrRegister(windowId: windowId, macApp: self)
    }

    func nativeFocusAsync(_ windowId: UInt32) {
        withWindowInBg(windowId) { [nsApp] window, job in
            // Raise firstly to make sure that by the time we activate the app, the window would be already on top
            window.set(Ax.isMainAttr, true)
            _ = window.raise()
            nsApp.activate(options: .activateIgnoringOtherApps)
        }
    }

    private var setFrameJob: RunLoopJob? = nil
    func setFrameAsync(_ windowId: UInt32, _ topLeft: CGPoint?, _ size: CGSize?) {
        setFrameJob?.cancel()
        setFrameJob = withWindowInBg(windowId) { [axApp] window, job in
            disableAnimations(app: axApp.unsafe) {
                _setFrame(window, topLeft, size)
            }
        }
    }

    @MainActor // todo swift is stupid
    func setAxFrameDuringTermination(_ windowId: UInt32, _ topLeft: CGPoint?, _ size: CGSize?) async throws {
        setFrameJob?.cancel()
        try await withWindow(windowId) { [axApp] window, job in
            disableAnimations(app: axApp.unsafe) {
                _setFrame(window, topLeft, size)
            }
        }
    }

    func setSizeAsync(_ windowId: UInt32, _ size: CGSize) {
        setFrameJob?.cancel()
        setFrameJob = withWindowInBg(windowId) { [axApp] window, job in
            disableAnimations(app: axApp.unsafe) {
                _ = window.set(Ax.sizeAttr, size)
            }
        }
    }

    func setTopLeftCornerAsync(_ windowId: UInt32, _ point: CGPoint) {
        setFrameJob?.cancel()
        setFrameJob = withWindowInBg(windowId) { [axApp] window, job in
            disableAnimations(app: axApp.unsafe) {
                _ = window.set(Ax.topLeftCornerAttr, point)
            }
        }
    }

    @MainActor // todo swift is stupid
    func getWindowsCount() async throws -> Int? {
        try await getThreadOrCancel().runInLoop { [axApp] job in
            axApp.unsafe.get(Ax.windowsAttr)?.count
        }
    }

    @MainActor // todo swift is stupid
    func getTopLeftCorner(_ windowId: UInt32) async throws -> CGPoint? {
        try await withWindow(windowId) { window, job in
            window.get(Ax.topLeftCornerAttr)
        }
    }

    @MainActor // todo swift is stupid
    func getRect(_ windowId: UInt32) async throws -> Rect? {
        try await withWindow(windowId) { window, job in
            guard let topLeftCorner = window.get(Ax.topLeftCornerAttr) else { return nil }
            guard let size = window.get(Ax.sizeAttr) else { return nil }
            return Rect(topLeftX: topLeftCorner.x, topLeftY: topLeftCorner.y, width: size.width, height: size.height)
        }
    }

    @MainActor // todo swift is stupid
    func isWindow(_ windowId: UInt32) async throws -> Bool {
        try await withWindow(windowId) { [axApp, id] window, job in
            window.isWindowHeuristic(axApp: axApp.unsafe, appBundleId: id)
        } == true
    }

    @MainActor // todo swift is stupid
    func isDialogHeuristic(_ windowId: UInt32) async throws -> Bool {
        try await withWindow(windowId) { [nsApp] window, job in
            window.isDialogHeuristic(nsApp)
        } == true
    }

    func setNativeFullscreenAsync(_ windowId: UInt32, _ value: Bool) {
        withWindowInBg(windowId) { window, job in
            window.set(Ax.isFullscreenAttr, value)
        }
    }

    func setNativeMinimizedAsync(_ windowId: UInt32, _ value: Bool) {
        withWindowInBg(windowId) { window, job in
            window.set(Ax.minimizedAttr, value)
        }
    }

    @MainActor // todo swift is stupid
    func dumpWindowAx(windowId: UInt32, _ prefix: String) async throws -> String {
        try await withWindow(windowId) { window, job in
            dumpAx(window, prefix, .window)
        } ?? ""
    }

    @MainActor // todo swift is stupid
    func getTitle(_ windowId: UInt32) async throws -> String? {
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
    func dumpAppAx(_ prefix: String) async throws -> String {
        try await getThreadOrCancel().runInLoop { [axApp] job in
            dumpAx(axApp.unsafe, prefix, .app)
        }
    }

    @MainActor func detectNewWindows(startup: Bool) async throws {
        error("todo")
    }

    @MainActor
    private func garbageCollect(skipClosedWindowsCache: Bool) { // todo try to convert to deinit
        MacApp.allAppsMap.removeValue(forKey: nsApp.processIdentifier)
        MacWindow.allWindows.lazy.filter { $0.app.pid == self.pid }.forEach { $0.garbageCollect(skipClosedWindowsCache: skipClosedWindowsCache) }
        thread?.runInLoopAsync { [appAxObservers] job in
            unsubscribeAxObservers(appAxObservers.unsafe)
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
        thread = nil // Disallow all future job submissions
    }

    @MainActor
    static func garbageCollectTerminatedApps() {
        for app in allAppsMap.values where app.nsApp.isTerminated {
            app.garbageCollect(skipClosedWindowsCache: true)
        }
    }

    private func getThreadOrCancel() throws -> Thread { // todo convert untyped throws to throws across the whole app
        if let thread { return thread }
        throw CancellationError()
    }

    @MainActor // todo swift is stupid
    private func withWindow<T>(_ windowId: UInt32, _ body: @Sendable @escaping (AXUIElement, RunLoopJob) -> T?) async throws -> T? {
        try await getThreadOrCancel().runInLoop { [windows] job in
            guard let window = windows.unsafe[windowId] else { return nil }
            return body(window.ax, job)
        }
    }

    @discardableResult
    private func withWindowInBg(_ windowId: UInt32, _ body: @Sendable @escaping (AXUIElement, RunLoopJob) -> ()) -> RunLoopJob {
        thread?.runInLoopAsync { [windows] job in
            guard let window = windows.unsafe[windowId] else { return }
            body(window.ax, job)
        } ?? .cancelled
    }
}

private class AxWindow { // todo properly destroy the window
    let windowId: UInt32
    let ax: AXUIElement
    private let axObservers: [AxObserverWrapper] // keep observers in memory

    private init(windowId: UInt32, _ ax: AXUIElement, _ axObservers: [AxObserverWrapper]) {
        self.windowId = windowId
        self.ax = ax
        self.axObservers = axObservers
    }

    static func new(windowId: UInt32, _ ax: AXUIElement, _ nsApp: NSRunningApplication) -> AxWindow? {
        var observers: [AxObserverWrapper] = []
        guard let id = ax.containingWindowId() else { return nil }
        if observe(refreshObs, ax, nsApp, kAXUIElementDestroyedNotification, &observers) &&
            observe(refreshObs, ax, nsApp, kAXWindowDeminiaturizedNotification, &observers) &&
            observe(refreshObs, ax, nsApp, kAXWindowMiniaturizedNotification, &observers) &&
            observe(movedObs, ax, nsApp, kAXMovedNotification, &observers) &&
            observe(resizedObs, ax, nsApp, kAXResizedNotification, &observers)
        {
            return AxWindow(windowId: id, ax, observers)
        } else {
            unsubscribeAxObservers(observers)
            return nil
        }
    }
}

private func getOrRegisterAxWindow(_ axWindow: AXUIElement, _ windows: [UInt32: AxWindow], _ nsApp: NSRunningApplication) -> AxWindow? {
    guard let id = axWindow.containingWindowId() else { return nil }
    if let existing = windows[id] {
        return existing
    } else {
        // Delay new window detection if mouse is down
        // It helps with apps that allow dragging their tabs out to create new windows
        // https://github.com/nikitabobko/AeroSpace/issues/1001
        if isLeftMouseButtonDown { return nil }

        return AxWindow.new(windowId: id, axWindow, nsApp)
    }
}

private func _setFrame(_ window: AXUIElement, _ topLeft: CGPoint?, _ size: CGSize?) {
    // Set size and then the position. The order is important https://github.com/nikitabobko/AeroSpace/issues/143
    //                                                        https://github.com/nikitabobko/AeroSpace/issues/335
    if let size { window.set(Ax.sizeAttr, size) }
    if let topLeft { window.set(Ax.topLeftCornerAttr, topLeft) } else { return }
    if let size { window.set(Ax.sizeAttr, size) }
}

private func observe(
    _ handler: AXObserverCallback,
    _ ax: AXUIElement,
    _ nsApp: NSRunningApplication,
    _ notifKey: String,
    _ observers: inout [AxObserverWrapper]
) -> Bool {
    guard let observer = AXObserver.observe(nsApp.processIdentifier, notifKey, ax, handler, data: nil) else { return false }
    observers.append(AxObserverWrapper(obs: observer, ax: ax, notif: notifKey as CFString))
    return true
}

private func unsubscribeAxObservers(_ observers: [AxObserverWrapper]) {
    for obs in observers {
        AXObserverRemoveNotification(obs.obs, obs.ax, obs.notif)
    }
}

// Some undocumented magic
// References: https://github.com/koekeishiya/yabai/commit/3fe4c77b001e1a4f613c26f01ea68c0f09327f3a
//             https://github.com/rxhanson/Rectangle/pull/285
private func disableAnimations<T>(app: AXUIElement, _ body: () -> T) -> T {
    let wasEnabled = app.get(Ax.enhancedUserInterfaceAttr) == true
    if wasEnabled {
        app.set(Ax.enhancedUserInterfaceAttr, false)
    }
    let result = body()
    if wasEnabled {
        app.set(Ax.enhancedUserInterfaceAttr, true)
    }
    return result
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

    @MainActor
    var macApp: MacApp? { get async throws { try await MacApp.get(self) } }
}

// var allAppsMap: Bar = Bar()

// public struct NonSendable {
//     func foo() {}
// }
//
// actor Foo {
//     let foo: NonSendable
//
//     init(foo: NonSendable) {
//         self.foo = foo
//     }
// }
//
// func foo() {
//     let bar = NonSendable()
//     let foo = Foo(foo: bar)
//     bar.foo()
// }
