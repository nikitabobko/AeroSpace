class TilingContainer: TreeNode, NonLeafTreeNode {
    var orientation: Orientation
    var layout: Layout
    override var parent: NonLeafTreeNode { super.parent ?? errorT("TilingContainers always have parent") }

    init(parent: NonLeafTreeNode, adaptiveWeight: CGFloat, _ orientation: Orientation, _ layout: Layout, index: Int) {
        self.orientation = orientation
        self.layout = layout
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    static func newHList(parent: NonLeafTreeNode, adaptiveWeight: CGFloat, index: Int) -> TilingContainer {
        TilingContainer(parent: parent, adaptiveWeight: adaptiveWeight, .H, .List, index: index)
    }

    static func newVList(parent: NonLeafTreeNode, adaptiveWeight: CGFloat, index: Int) -> TilingContainer {
        TilingContainer(parent: parent, adaptiveWeight: adaptiveWeight, .V, .List, index: index)
    }
}

extension TilingContainer {
    func normalizeContainersRecursive() {
        if let child = children.singleOrNil() as? TilingContainer, config.autoFlattenContainers {
            child.unbindFromParent()
            let parent = parent
            let previousBinding = unbindFromParent()
            child.bindTo(parent: parent, adaptiveWeight: previousBinding.adaptiveWeight, index: previousBinding.index)
            child.normalizeContainersRecursive()
        } else {
            for child in children {
                (child as? TilingContainer)?.normalizeContainersRecursive()
            }
            if children.isEmpty && !isRootContainer {
                unbindFromParent()
            }
        }
    }

    var ownIndex: Int { parent.children.firstIndex(of: self)! }
    var isRootContainer: Bool { parent is Workspace }
}

enum Orientation {
    /// Windows are planced along the **horizontal** line
    case H
    /// Windows are planced along the **vertical** line
    case V
}

extension Orientation {
    var opposite: Orientation { self == .H ? .V : .H }
}

enum Layout {
    case List
    case Accordion
}
