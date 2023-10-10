@testable import AeroSpace_Debug

extension TilingContainer {
    static func newHList(parent: TreeNode, adaptiveWeight: CGFloat) -> TilingContainer {
        newHList(parent: parent, adaptiveWeight: adaptiveWeight, index: BIND_LAST_INDEX)
    }

    static func newVList(parent: TreeNode, adaptiveWeight: CGFloat) -> TilingContainer {
        newVList(parent: parent, adaptiveWeight: adaptiveWeight, index: BIND_LAST_INDEX)
    }
}
