@testable import AppBundle
import AppKit

final class TestWindow: Window, CustomStringConvertible {
    private var _rect: Rect?

    @discardableResult
    init(id: UInt32, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat = 1, rect: Rect? = nil) {
        _rect = rect
        super.init(id: id, TestApp.shared, lastFloatingSize: nil, parent: parent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
        TestApp.shared._windows.append(self)
    }

    var description: String { "TestWindow(\(windowId))" }

    @discardableResult
    override func nativeFocus() -> Bool {
        appForTests = TestApp.shared
        TestApp.shared.focusedWindow = self
        return true
    }

    override var title: String { description }

    override func getRect() -> Rect? { // todo change to not Optional
        _rect
    }
}
