@testable import AeroSpace_Debug

extension TilingContainer {
    static func newHTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat) -> TilingContainer {
        newHTiles(parent: parent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
    }

    static func newVTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat) -> TilingContainer {
        newVTiles(parent: parent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
    }
}
