@testable import AeroSpace_Debug

final class TestWindow: Window {
    override init(id: UInt32, parent: TreeNode, adaptiveWeight: CGFloat) {
        super.init(id: id, parent: parent, adaptiveWeight: adaptiveWeight)
    }

    override func focus() -> Bool { error("TODO") }
}
