import Foundation

protocol TreeNode {
    var children: [TreeNode] { get }
}

extension TreeNode {
    private func visit(node: TreeNode, result: inout [MacWindow]) {
        if let node = node as? MacWindow {
            result.append(node)
        }
        for child in node.children {
            visit(node: child, result: &result)
        }
    }

    var allWindows: [MacWindow] {
        var result: [MacWindow] = []
        visit(node: self, result: &result)
        return result
    }
}
