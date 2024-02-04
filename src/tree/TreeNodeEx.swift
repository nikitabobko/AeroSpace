import Common

extension TreeNode {
    private func visit(node: TreeNode, result: inout [Window]) {
        if let node = node as? Window {
            result.append(node)
        }
        for child in node.children {
            visit(node: child, result: &result)
        }
    }
    var allLeafWindowsRecursive: [Window] {
        var result: [Window] = []
        visit(node: self, result: &result)
        return result
    }

    var ownIndexOrNil: Int? {
        guard let parent else { return nil }
        return parent.children.firstIndex(of: self)!
    }

    var parents: [NonLeafTreeNodeObject] { parent.flatMap { [$0] + $0.parents } ?? [] }
    var parentsWithSelf: [TreeNode] { parent.flatMap { [self] + $0.parentsWithSelf } ?? [self] }

    var workspace: Workspace? {
        self as? Workspace ?? parent?.workspace
    }

    var nodeMonitor: Monitor? {
        guard let parent else { return nil }
        switch parent.cases {
        case .workspace(let parent):
            return parent.monitor
        case .tilingContainer(let parent):
            return parent.nodeMonitor
        case .macosInvisibleWindowsContainer:
            return nil
        }
    }

    var mostRecentWindow: Window? {
        self as? Window ?? mostRecentChild?.mostRecentWindow
    }

    var anyLeafWindowRecursive: Window? {
        if let window = self as? Window {
            return window
        }
        for child in children {
            if let window = child.anyLeafWindowRecursive {
                return window
            }
        }
        return nil
    }

    // Doesn't contain at least one window
    var isEffectivelyEmpty: Bool {
        anyLeafWindowRecursive == nil
    }

    var hWeight: CGFloat {
        get { getWeight(.h) }
        set { setWeight(.h, newValue) }
    }

    var vWeight: CGFloat {
        get { getWeight(.v) }
        set { setWeight(.v, newValue) }
    }

    func getCenter() -> CGPoint? { getRect()?.center }

    /// Returns closest parent that has children in specified direction relative to `self`
    func closestParent(
        hasChildrenInDirection direction: CardinalDirection,
        withLayout layout: Layout?
    ) -> (parent: TilingContainer, ownIndex: Int)? {
        let innermostChild = parentsWithSelf.first(where: { (node: TreeNode) -> Bool in
            switch node.parent?.cases {
            case .workspace, nil, .macosInvisibleWindowsContainer:
                return true // stop searching
            case .tilingContainer(let parent):
                return (layout == nil || parent.layout == layout) &&
                    parent.orientation == direction.orientation &&
                    parent.children.indices.contains(node.ownIndexOrNil! + direction.focusOffset)
            }
        })!
        switch innermostChild.parent?.cases {
        case .tilingContainer(let parent):
            check(parent.orientation == direction.orientation)
            return (parent, innermostChild.ownIndexOrNil!)
        case .workspace, nil, .macosInvisibleWindowsContainer:
            return nil
        }
    }
}
