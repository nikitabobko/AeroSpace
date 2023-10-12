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

    var parents: [TreeNode] { parent.flatMap { [$0] + $0.parents } ?? [] }
    var parentsWithSelf: [TreeNode] { parent.flatMap { [self] + $0.parentsWithSelf } ?? [self] }

    var workspace: Workspace {
        self as? Workspace ?? parent?.workspace ?? errorT("Unknown type \(Self.self)")
    }

    var mostRecentWindow: Window? {
        self as? Window ?? mostRecentChild?.mostRecentWindow
    }

    var mostRecentWindowForAccordion: Window? {
        self as? Window ?? mostRecentChildIndexForAccordion?
            .lets { children.getOrNil(atIndex: $0) }?.mostRecentWindowForAccordion
    }

    func resetMruForAccordionRecursive() {
        mostRecentChildIndexForAccordion = nil
        for child in children {
            child.resetMruForAccordionRecursive()
        }
    }

    func allLeafWindowsRecursive(snappedTo direction: CardinalDirection) -> [Window] {
        switch kind {
        case .workspace(let workspace):
            return workspace.rootTilingContainer.allLeafWindowsRecursive(snappedTo: direction)
        case .window(let window):
            return [window]
        case .tilingContainer(let container):
            if direction.orientation == container.orientation {
                return (direction.isPositive ? container.children.last : container.children.first)?
                    .allLeafWindowsRecursive(snappedTo: direction) ?? []
            } else {
                return children.flatMap { $0.allLeafWindowsRecursive(snappedTo: direction) }
            }
        }
    }

    var mostRecentChild: TreeNode? {
        var iterator = mostRecentChildren.makeIterator()
        return iterator.next()
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
        get { getWeight(.H) }
        set { setWeight(.H, newValue) }
    }

    var vWeight: CGFloat {
        get { getWeight(.V) }
        set { setWeight(.V, newValue) }
    }

    func getCenter() -> CGPoint? { getRect()?.center }

    var kind: TreeNodeKind {
        if let window = self as? Window {
            return .window(window)
        } else if let workspace = self as? Workspace {
            return .workspace(workspace)
        } else if let tilingContainer = self as? TilingContainer {
            return .tilingContainer(tilingContainer)
        } else {
            error("Unknown tree")
        }
    }

    /// Returns closest parent that has children in specified direction relative to `self`
    func closestParent(
        hasChildrenInDirection direction: CardinalDirection,
        withLayout layout: Layout?
    ) -> (parent: TilingContainer, ownIndex: Int)? {
        let innermostChild = parentsWithSelf.first(where: { (node: TreeNode) -> Bool in
            switch node.parent?.kind {
            case .workspace:
                return true
            case .tilingContainer(let parent):
                return (layout == nil || parent.layout == layout) &&
                    parent.orientation == direction.orientation &&
                    parent.children.indices.contains(node.ownIndexOrNil! + direction.focusOffset)
            case .window:
                windowsCantHaveChildren()
            case nil:
                return true
            }
        })!
        if let parent = innermostChild.parent as? TilingContainer {
            precondition(parent.orientation == direction.orientation)
            return (parent, innermostChild.ownIndexOrNil!)
        } else {
            return nil
        }
    }
}
