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

    var allWindowsRecursive: [MacWindow] {
        var result: [MacWindow] = []
        visit(node: self, result: &result)
        return result
    }
}
