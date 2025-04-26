@testable import AppBundle
import AppKit

extension TilingContainer {
    @MainActor
    static func newHTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat) -> TilingContainer {
        newHTiles(parent: parent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
    }

    @MainActor
    static func newVTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat) -> TilingContainer {
        newVTiles(parent: parent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
    }
}
