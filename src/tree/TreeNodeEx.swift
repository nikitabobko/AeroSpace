import Foundation

extension TreeNode {
    private func visit(node: TreeNode, result: inout [MacWindow]) {
        if let node = node as? MacWindow {
            result.append(node)
        }
        for child in node.children {
            visit(node: child, result: &result)
        }
    }
    var allLeafWindowsRecursive: [MacWindow] {
        var result: [MacWindow] = []
        visit(node: self, result: &result)
        return result
    }

    var parents: [TreeNode] { self is Workspace ? [] : [parent] + parent.parents }
    var parentsWithSelf: [TreeNode] { self is Workspace ? [self] : [self] + parent.parentsWithSelf }

    var workspace: Workspace {
        self as? Workspace ?? parent.workspace
    }

    func allLeafWindowsRecursive(snappedTo direction: CardinalDirection) -> [MacWindow] {
        if let workspace = self as? Workspace {
            return workspace.rootTilingContainer.allLeafWindowsRecursive(snappedTo: direction)
        } else if let window = self as? MacWindow {
            return [window]
        } else if let container = self as? TilingContainer {
            if direction.orientation == container.orientation {
                return (direction.isPositive ? container.children.last : container.children.first)?
                    .allLeafWindowsRecursive(snappedTo: direction) ?? []
            } else {
                return children.flatMap { $0.allLeafWindowsRecursive(snappedTo: direction) }
            }
        } else {
            error("Not supported TreeNode type: \(Self.self)")
        }
    }

    var anyLeafWindowRecursive: MacWindow? {
        if let window = children.first(where: { $0 is MacWindow }) {
            return (window as! MacWindow)
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

    /// Containers' weights must be normalized before calling this function
    func layoutRecursive(_ _point: CGPoint, width: CGFloat, height: CGFloat) {
        if let workspace = self as? Workspace {
            workspace.rootTilingContainer.layoutRecursive(_point, width: width, height: height)
        } else if let window = self as? MacWindow {
            window.setTopLeftCorner(_point)
            window.setSize(CGSize(width: width, height: height))
        } else if let container = self as? TilingContainer {
            var point = _point
            for child in container.children {
                switch container.layout {
                case .Accordion: // todo layout with accordion offset
                    child.layoutRecursive(point, width: width, height: height)
                case .List:
                    child.layoutRecursive(point, width: child.hWeight, height: child.vWeight)
                    switch container.orientation {
                    case .H:
                        point = point.copy(x: point.x + child.hWeight)
                    case .V:
                        point = point.copy(y: point.y + child.vWeight)
                    }
                }
            }
        } else {
            error("Not supported TreeNode type: \(Self.self)")
        }
    }
}
