import Foundation
import AppKit

class Window: TreeNode {
    private let nsApp: NSRunningApplication
    // todo: make private
    let axWindow: AXUIElement
    // todo: make private
    let axApp: AXUIElement
    var children: [TreeNode] {
        []
    }
    private var lastNotHiddenPosition: CGPoint?

    init(nsApp: NSRunningApplication, axApp: AXUIElement, axWindow: AXUIElement) {
        self.nsApp = nsApp
        self.axApp = axApp
        self.axWindow = axWindow
    }

    var title: String? {
        axWindow.get(Ax.titleAttr)
    }

    func activate() -> Bool {
        nsApp.activate(options: .activateIgnoringOtherApps)
        return AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString) == AXError.success
    }

    func close() -> Bool {
        guard let closeButton = axWindow.get(Ax.closeButtonAttr) else { return false }
        return AXUIElementPerformAction(closeButton, kAXPressAction as CFString) == AXError.success
    }

    func hide() -> Bool {
        lastNotHiddenPosition = getPosition()
//        return setPosition(CGPoint(x: monitorWidth, y: monitorHeight))
        return setPosition(CGPoint(x: monitorWidth + 1000, y: monitorHeight))
    }

    func unhide() -> Bool {
        guard let lastNotHiddenPosition else { return false }
        self.lastNotHiddenPosition = nil
        return setPosition(lastNotHiddenPosition)
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
        isHiddenApp || lastNotHiddenPosition != nil
    }

    func setSize(_ size: CGSize) -> Bool {
        assert(axWindow.set(Ax.sizeAttr, size))
        return true
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
}
