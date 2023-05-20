import Foundation
import AppKit

class Window: TreeNode {
    private let nsApp: NSRunningApplication
    private let axWindow: AXUIElement
    var children: [TreeNode] {
        []
    }
    private var lastNotHiddenPosition: CGPoint?

    init(nsApp: NSRunningApplication, axWindow: AXUIElement) {
        self.nsApp = nsApp
        self.axWindow = axWindow
    }

    var title: String? {
        axWindow.get(Ax.titleAttr)
    }

    func activate() {
        // todo it activates the app, not the window right?
        nsApp.activate(options: .activateIgnoringOtherApps)
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
