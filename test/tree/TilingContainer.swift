@testable import AeroSpace_Debug

extension TilingContainer {
    static func newHList(parent: NonLeafTreeNode, adaptiveWeight: CGFloat) -> TilingContainer {
        newHList(parent: parent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
    }

    static func newVList(parent: NonLeafTreeNode, adaptiveWeight: CGFloat) -> TilingContainer {
        newVList(parent: parent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
    }
}
