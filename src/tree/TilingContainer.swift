class TilingContainer: TreeNode, NonLeafTreeNode {
    fileprivate var _orientation: Orientation
    var orientation: Orientation { _orientation }
    var layout: Layout
    override var parent: NonLeafTreeNode { super.parent ?? errorT("TilingContainers always have parent") }

    init(parent: NonLeafTreeNode, adaptiveWeight: CGFloat, _ orientation: Orientation, _ layout: Layout, index: Int) {
        self._orientation = orientation
        self.layout = layout
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    static func newHList(parent: NonLeafTreeNode, adaptiveWeight: CGFloat, index: Int) -> TilingContainer {
        TilingContainer(parent: parent, adaptiveWeight: adaptiveWeight, .h, .list, index: index)
    }

    static func newVList(parent: NonLeafTreeNode, adaptiveWeight: CGFloat, index: Int) -> TilingContainer {
        TilingContainer(parent: parent, adaptiveWeight: adaptiveWeight, .v, .list, index: index)
    }
}

extension TilingContainer {
    var ownIndex: Int { parent.children.firstIndex(of: self)! }
    var isRootContainer: Bool { parent is Workspace }

    func changeOrientation(_ targetOrientation: Orientation) {
        if orientation == targetOrientation {
            return
        }
        if config.enableNormalizationOppositeOrientationForNestedContainers {
            var orientation = targetOrientation
            parent.parentsWithSelf
                .prefix(while: { $0 is TilingContainer })
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

enum Orientation {
    /// Windows are planced along the **horizontal** line
    /// x-axis
    case h
    /// Windows are planced along the **vertical** line
    /// y-axis
    case v
}

extension Orientation {
    var opposite: Orientation { self == .h ? .v : .h }
}

enum Layout: String {
    case list
    case accordion
}
