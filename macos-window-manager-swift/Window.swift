import Foundation
import AppKit

class Window: TreeNode {
    private let nsApp: NSRunningApplication
    private let axWindow: AXUIElement
    var children: [TreeNode] {
        []
    }

    init(nsApp: NSRunningApplication, axWindow: AXUIElement) {
        self.nsApp = nsApp
        self.axWindow = axWindow
    }

    var title: String? {
        axWindow.get(Ax.titleAttr)
    }

    func activate() {
        nsApp.activate(options: .activateIgnoringOtherApps)
    }

    func hide() -> Bool {
        nsApp.hide()
    }

    func unhide() -> Bool {
        nsApp.unhide()
    }

    var isHidden: Bool {
        nsApp.isHidden
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
