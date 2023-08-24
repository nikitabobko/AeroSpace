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

    // todo drop. because performance
    var allWindowsRecursive: [MacWindow] {
        var result: [MacWindow] = []
        visit(node: self, result: &result)
        return result
    }

    var workspace: Workspace {
        if let workspace = self as? Workspace {
            return workspace
        } else {
            return parent.workspace
        }
    }

    var anyChildWindowRecursive: MacWindow? {
        if let window = children.first(where: { $0 is MacWindow }) {
            return (window as! MacWindow)
        }
        for child in children {
            if let window = child.anyChildWindowRecursive {
                return window
            }
        }
        return nil
    }

    // Doesn't contain at least one window
    var isEffectivelyEmpty: Bool {
        anyChildWindowRecursive == nil
    }
}
