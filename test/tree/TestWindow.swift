@testable import AeroSpace_Debug

final class TestWindow: Window {
    private let focusManager: TestFocusManager

    init(id: UInt32, parent: TreeNode, adaptiveWeight: CGFloat, focusManager: TestFocusManager) {
        self.focusManager = focusManager
        super.init(id: id, parent: parent, adaptiveWeight: adaptiveWeight)
    }

    override func focus() -> Bool {
        focusManager.focusedNode = self
        return true
    }
}

class TestFocusManager {
    var focusedNode: TreeNode? = nil
}
