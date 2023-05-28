import Foundation

protocol TreeNode {
    var children: [TreeNode] { get }
}

extension TreeNode {
    private func visit(node: TreeNode, result: inout [Window]) {
        if let node = node as? Window {
            result.append(node)
        }
        for child in node.children {
            visit(node: child, result: &result)
        }
    }

    var allWindows: [Window] {
        var result: [Window] = []
        visit(node: self, result: &result)
        return result
    }
}
