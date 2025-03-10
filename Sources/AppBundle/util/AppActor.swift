import AppKit
import Common

func foo(app: Foo) async {
    await app.foo()
}

// Don't convert to AppActor.static https://github.com/swiftlang/swift/issues/78435
@MainActor
var allAppsMap: [pid_t: AppActor] = [:]

class Foo {
    nonisolated let pid: Int32
    nonisolated let bundleId: String?
    nonisolated let nsApp: NSRunningApplication
    private let axApp: SendableAxUiElement
    // private var windows: [UInt32: SendableAxUiElement] = [:]
    let thread: Thread

    private init(_ nsApp: NSRunningApplication, _ axApp: AXUIElement, _ thread: Thread) {
        self.pid = nsApp.processIdentifier
        self.bundleId = nsApp.bundleIdentifier
        self.nsApp = nsApp
        self.axApp = SendableAxUiElement(axApp)
        self.thread = thread
    }

    @MainActor
    func foo() {
    }
}

// Potential alternative implementation
// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md
// (only available since macOS 14)
//
// Or it could be a class + @MainActor to avoid potential unnecessary context switches
actor AppActor {
    nonisolated let pid: Int32
    nonisolated let bundleId: String?
    nonisolated let nsApp: NSRunningApplication
    private let axApp: SendableAxUiElement
    private var windows: [UInt32: SendableAxUiElement] = [:]
    let thread: Thread

    private init(_ nsApp: NSRunningApplication, _ axApp: AXUIElement, _ thread: Thread) {
        // self.ax = ax
        self.pid = nsApp.processIdentifier
        self.bundleId = nsApp.bundleIdentifier
        self.nsApp = nsApp
        self.axApp = SendableAxUiElement(axApp)
        self.thread = thread
    }

    @MainActor
    static func get(_ nsApp: NSRunningApplication) -> AppActor? {
        // Don't perceive any of the lock screen windows as real windows
        // Otherwise, false positive ax notifications might trigger that lead to gcWindows
        if nsApp.bundleIdentifier == lockScreenAppBundleId {
            return nil
        }
        let pid = nsApp.processIdentifier
        if let existing = allAppsMap[pid] {
            return existing
        } else {
            // let app = AppActor(nsApp, AXUIElementCreateApplication(nsApp.processIdentifier))
            //
            // // self.thread.name = "app-dedicated-thread pid=\(pid) \(bundleId ?? nsApp.executableURL?.description ?? "")"
            //
            // if app.observe(refreshObs, kAXWindowCreatedNotification) &&
            //     app.observe(refreshObs, kAXFocusedWindowChangedNotification)
            // {
            //     allAppsMap[pid] = app
            //     return app
            // } else {
            //     app.garbageCollect(skipClosedWindowsCache: true)
            //     return nil
            // }
            error()
        }
    }

    func closeWindow(_ windowId: UInt32) async -> Bool {
        await withWindow(windowId) { window in
            guard let closeButton = window.get(Ax.closeButtonAttr) else { return false }
            if AXUIElementPerformAction(closeButton, kAXPressAction as CFString) != AXError.success { return false }
            return true
        } == true
    }

    nonisolated func nativeFocusAsync(_ windowId: UInt32) {
        withWindowAsync(windowId) { window in
            // Raise firstly to make sure that by the time we activate the app, the window would be already on top
            window.set(Ax.isMainAttr, true)
            _ = window.raise()
            self.nsApp.activate(options: .activateIgnoringOtherApps)
        }
    }

    // todo: cancel previous requests
    // todo invert the nesting? once the TreeNode structure is sendable and immutable, we could send it to all AppActors
    nonisolated func setFrameAsync(_ windowId: UInt32, _ topLeft: CGPoint?, _ size: CGSize?) {
        guard let window = windows[windowId] else { return }
        thread.runInLoopAsync {
            let window = window.unsafe
            disableAnimations(app: self.axApp.unsafe) {
                // Set size and then the position. The order is important https://github.com/nikitabobko/AeroSpace/issues/143
                //                                                        https://github.com/nikitabobko/AeroSpace/issues/335
                if let size { window.set(Ax.sizeAttr, size) }
                if let topLeft { window.set(Ax.topLeftCornerAttr, topLeft) } else { return }
                if let size { window.set(Ax.sizeAttr, size) }
            }
        }
    }

    func getTopLeftCorner(_ windowId: UInt32) async -> CGPoint? {
        await withWindow(windowId) { window in
            window.get(Ax.topLeftCornerAttr)
        }
    }

    func getRect(_ windowId: UInt32) async -> Rect? {
        await withWindow(windowId) { window in
            guard let topLeftCorner = window.get(Ax.topLeftCornerAttr) else { return nil }
            guard let size = window.get(Ax.sizeAttr) else { return nil }
            return Rect(topLeftX: topLeftCorner.x, topLeftY: topLeftCorner.y, width: size.width, height: size.height)
        }
    }

    func isWindow(_ windowId: UInt32) async -> Bool {
        await withWindow(windowId) { window in
            isWindowImpl(axWindow: window, axApp: self.axApp.unsafe, appBundleId: self.bundleId)
        } == true
    }

    func setNativeFullscreen(_ windowId: UInt32, _ value: Bool) async -> Bool {
        await withWindow(windowId) { window in
            window.set(Ax.isFullscreenAttr, value)
        } == true
    }

    // func gcWindowsAsync(frontmostAppBundleId: String) {
    //     // Second line of defence against lock screen. See the first line of defence: closedWindowsCache
    //     // Second and third lines of defence are technically needed only to avoid potential flickering
    //     if frontmostAppBundleId == lockScreenAppBundleId { return }
    //     let windows = windows
    //     thread.runInLoopAsync {
    //         let toKill = windows.filter { $0.value.unsafe.containingWindowId(signpostEvent: bundleId) == nil }
    //         // If all windows are "unobservable", it's highly propable that loginwindow might be still active and we are still
    //         // recovering from unlock
    //         if toKill.count == windows.count { return }
    //         for window in toKill {
    //             window.value.unsafe.garbageCollect(skipClosedWindowsCache: false) // todo
    //         }
    //     }
    // }

    func setNativeMinimized(_ windowId: UInt32, _ value: Bool) async -> Bool {
        await withWindow(windowId) { window in
            window.set(Ax.minimizedAttr, value)
        } == true
    }

    private func withWindow<T>(_ windowId: UInt32, _ body: @Sendable @escaping (AXUIElement) -> T?) async -> T? {
        guard let window = windows[windowId] else { return nil }
        return await thread.runInLoop {
            let window = window.unsafe
            return body(window)
        }
    }

    nonisolated private func withWindowAsync(_ windowId: UInt32, _ body: @Sendable @escaping (AXUIElement) -> ()) {
        Task {
            await withWindowAsync(windowId, body)
        }
    }

    private func withWindowAsync(_ windowId: UInt32, _ body: @Sendable @escaping (AXUIElement) -> ()) async {
        guard let window = windows[windowId] else { return }
        thread.runInLoopAsync {
            let window = window.unsafe
            body(window)
        }
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

public final class UnsafeSendable<T>: Sendable {
    nonisolated(unsafe) let unsafe: T
    public init(_ value: T) { self.unsafe = value }
}

// Properties of this class should only be accessed in the guard thread
// It's unsafe to access `unsafe` property of this struct in AppActor
private final class SendableAxUiElement: Sendable {
    nonisolated(unsafe) let unsafe: AXUIElement
    fileprivate init(_ value: AXUIElement) { self.unsafe = value }
}

public typealias Continuation<T> = CheckedContinuation<T, Never>

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
