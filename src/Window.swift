import Foundation
import AppKit


class Window: TreeNode, Hashable {
    private let nsApp: NSRunningApplication
    // todo: make private
    let axWindow: AXUIElement
    // todo: make private
    // todo unused?
    let axApp: AXUIElement
    var children: [TreeNode] {
        []
    }
    private var prevUnhiddenPosition: CGPoint?
    private var previousSize: CGSize?
    private var observer: AXObserver? // keep observer in memory

    private init(_ nsApp: NSRunningApplication, _ axApp: AXUIElement, _ axWindow: AXUIElement) {
        self.nsApp = nsApp
        self.axApp = axApp
        self.axWindow = axWindow
    }

    // todo weak values?
    // todo do I need it?
    static private(set) var allWindows: [CGWindowID:Window] = [:]

    static func get(nsApp: NSRunningApplication, axApp: AXUIElement, axWindow: AXUIElement) -> Window? {
        guard let id = axWindow.windowId() else { return nil }
        if let existing = allWindows[id] {
            return existing
        } else {
            var window = Window(nsApp, axApp, axWindow)

            let windowPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(window).toOpaque())

            var observer: AXObserver? = nil
            assert(AXObserverCreate(nsApp.processIdentifier, handler, &observer) == .success)
            guard let observer else { fatalError("Window.get: observer") }
            window.observer = observer
            assert(AXObserverAddNotification(observer, axWindow, kAXMovedNotification as CFString, windowPtr) == .success)
            assert(AXObserverAddNotification(observer, axWindow, kAXResizedNotification as CFString, windowPtr) == .success)
//            assert(AXObserverAddNotification(observer!, axApp, kAXWindowCreatedNotification as CFString, &window) == .success)

            CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)

            allWindows[id] = window
            return window
        }
    }

//    public typealias AXObserverCallback = @convention(c) (AXObserver, AXUIElement, CFString, UnsafeMutableRawPointer?) -> Void

    var title: String? {
        axWindow.get(Ax.titleAttr)
    }

    var monitor: NSScreen? {
        guard let position = getPosition() else { return nil }
        return NSScreen.screens.first { $0.frame.contains(position) }
    }

    func windowId() -> CGWindowID {
        if let id = axWindow.windowId() {
            return id
        } else {
            fatalError("Can't get ID of \(self)")
        }
    }

    func activate() -> Bool {
        nsApp.activate(options: .activateIgnoringOtherApps)
        return AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString) == AXError.success
    }

    func close() -> Bool {
        guard let closeButton = axWindow.get(Ax.closeButtonAttr) else { return false }
        return AXUIElementPerformAction(closeButton, kAXPressAction as CFString) == AXError.success
    }

    // todo current approach breaks mission control (three fingers up the trackpad). Or is it only because of IDEA?
    // todo hypnotize: change size to cooperate with mission control (make it configurable)
    @discardableResult func hide() -> Bool {
        prevUnhiddenPosition = getPosition()
//        return setPosition(CGPoint(x: monitorWidth, y: monitorHeight))
        return setPosition(CGPoint(x: monitorWidth, y: monitorHeight))
    }

    @discardableResult func unhide() -> Bool {
        guard let prevUnhiddenPosition else { return false }
        self.prevUnhiddenPosition = nil
        return setPosition(prevUnhiddenPosition)
    }

    func hideApp() -> Bool {
        nsApp.hide()
    }

    // todo drop?
    func unhideApp() -> Bool {
        nsApp.unhide()
    }

    var isHiddenApp: Bool {
        nsApp.isHidden
    }

    var isHidden: Bool {
        isHiddenApp || prevUnhiddenPosition != nil
    }

    @discardableResult func setSize(_ size: CGSize) -> Bool {
        previousSize = getSize()
        return axWindow.set(Ax.sizeAttr, size)
    }

    func getSize() -> CGSize? {
        axWindow.get(Ax.sizeAttr)
    }

    func setPosition(_ position: CGPoint) -> Bool {
        axWindow.set(Ax.positionAttr, position)
    }

    func getPosition() -> CGPoint? {
        axWindow.get(Ax.positionAttr)
    }

    static func ==(lhs: Window, rhs: Window) -> Bool {
        lhs.windowId() == rhs.windowId()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(windowId())
    }
}

private func handler(
        _ observer: AXObserver,
        elem: AXUIElement,
        notification: CFString,
        userData: UnsafeMutableRawPointer?
) {
    let foo = userData?._rawValue
    print("notif \(foo)")
    Unmanaged<Window>.fromOpaque(userData!)
    guard let userData else { return }
    let window = Unmanaged<Window>.fromOpaque(userData).takeRetainedValue()
//    let window = userData as! Window
    print("notif \(window)")
}
