import Foundation

protocol TreeNode {
    var children: [TreeNode] { get }
}

extension TreeNode {
    private func visit(node: TreeNode, result: inout [Window]) {
        if (node is Window) {
            result.append(node as! Window)
        }
        for child in node.children {
            visit(node: child, result: &result)
        }
    }

    var allWindows: [Window] {
        get {
            var result: [Window] = []
            visit(node: self, result: &result)
            return result
        }
    }
}
