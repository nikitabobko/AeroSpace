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

    /// Containers' weights must be normalized before calling this function
    func layoutRecursive(_ point: CGPoint, width: CGFloat, height: CGFloat, firstStart: Bool) {
        let rect = Rect(topLeftX: point.x, topLeftY: point.y, width: width, height: height)
        switch kind {
        case .workspace(let workspace):
            workspace.lastAppliedLayoutRect = rect
            workspace.rootTilingContainer.layoutRecursive(point, width: width, height: height, firstStart: firstStart)
        case .window(let window):
            if window.windowId != currentlyResizedWithMouseWindowId {
                lastAppliedLayoutRect = rect
                window.setTopLeftCorner(point)
                window.setSize(CGSize(width: width, height: height))
                if firstStart { // It makes the layout more good-looking on the start. Good first impression
                    window.focus()
                }
            }
        case .tilingContainer(let container):
            container.lastAppliedLayoutRect = rect
            var childPoint = point
            for child in container.children {
                switch container.layout {
                case .Accordion: // todo layout with accordion offset
                    child.layoutRecursive(childPoint, width: width, height: height, firstStart: firstStart)
                case .List:
                    child.layoutRecursive(childPoint, width: child.hWeight, height: child.vWeight, firstStart: firstStart)
                    switch container.orientation {
                    case .H:
                        childPoint = childPoint.copy(x: childPoint.x + child.hWeight)
                    case .V:
                        childPoint = childPoint.copy(y: childPoint.y + child.vWeight)
                    }
                }
            }
        }
    }

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
    func closestParent(hasChildrenInDirection direction: CardinalDirection) -> (parent: TilingContainer, ownIndex: Int)? {
        let innermostChild = parentsWithSelf.first(where: { (node: TreeNode) -> Bool in
            switch node.parent?.kind {
            case .workspace:
                return true
            case .tilingContainer(let parent):
                return parent.orientation == direction.orientation &&
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
