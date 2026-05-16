import AppKit
import Common

final class TilingContainer: TreeNode, NonLeafTreeNodeObject { // todo consider renaming to GenericContainer
    fileprivate var _orientation: Orientation
    var orientation: Orientation { _orientation }
    var layout: Layout
    /// Number of windows that logically belong to this container but are currently
    /// detached because they are in macOS-unconventional state (native fullscreen,
    /// minimized, or hidden app). Such a window saves a `MacosPrev` pointing here
    /// and expects to come back. `unbindEmptyAndAutoFlatten` must treat the
    /// container as if these windows were still here -- otherwise an accordion
    /// with two children gets flattened the moment one of them enters fullscreen
    /// (only one actual child remaining), the parent ref in `MacosPrev` (weak)
    /// goes nil, and on exit the window lands at the root as a flat sibling
    /// instead of restoring into the accordion.
    @MainActor var pendingFullscreenChildren: Int = 0

    @MainActor
    init(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, _ orientation: Orientation, _ layout: Layout, index: Int) {
        self._orientation = orientation
        self.layout = layout
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor
    static func newHTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) -> TilingContainer {
        TilingContainer(parent: parent, adaptiveWeight: adaptiveWeight, .h, .tiles, index: index)
    }

    @MainActor
    static func newVTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) -> TilingContainer {
        TilingContainer(parent: parent, adaptiveWeight: adaptiveWeight, .v, .tiles, index: index)
    }
}

extension TilingContainer {
    var isRootContainer: Bool { parent is Workspace }

    @MainActor
    func changeOrientation(_ targetOrientation: Orientation) {
        if orientation == targetOrientation {
            return
        }
        if config.enableNormalizationOppositeOrientationForNestedContainers {
            var orientation = targetOrientation
            parentsWithSelf
                .filterIsInstance(of: TilingContainer.self)
                .forEach {
                    $0._orientation = orientation
                    orientation = orientation.opposite
                }
        } else {
            _orientation = targetOrientation
        }
    }

    func normalizeOppositeOrientationForNestedContainers() {
        if orientation == (parent as? TilingContainer)?.orientation {
            _orientation = orientation.opposite
        }
        for child in children {
            (child as? TilingContainer)?.normalizeOppositeOrientationForNestedContainers()
        }
    }
}

enum Layout: String {
    case tiles
    case accordion
}

extension String {
    func parseLayout() -> Layout? {
        switch Layout(rawValue: self) {
            case let parsed?: parsed
            case nil where self == "list": .tiles
            case nil: nil
        }
    }
}
