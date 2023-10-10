@testable import AeroSpace_Debug

final class TestWindow: Window, CustomStringConvertible {
    private var _rect: Rect?

    @discardableResult
    init(id: UInt32, parent: TreeNode, adaptiveWeight: CGFloat = 1, rect: Rect? = nil) {
        _rect = rect
        super.init(id: id, parent: parent, adaptiveWeight: adaptiveWeight, index: BIND_LAST_INDEX)
        TestApp.shared.windows.append(self)
    }

    var description: String { "TestWindow(\(windowId))" }

    @discardableResult
    override func focus() -> Bool {
        focusedAppForTests = TestApp.shared
        TestApp.shared.focusedWindow = self
        return true
    }

    override var title: String? { description }

    override func getRect() -> Rect? { // todo change to not Optional
        _rect
    }
}
