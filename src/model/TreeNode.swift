import Foundation

protocol TreeNode: AnyObject {
    var children: WeakArray<TreeNodeClass> { set get }
    var parent: TreeNode { get set }
}

/// Workaround for https://github.com/apple/swift/issues/48596
class TreeNodeClass {
    var value: TreeNode
    init(value: TreeNode) {
        self.value = value
    }
}

extension WeakArray where T == TreeNodeClass {
    mutating func derefTreeNode() -> [TreeNode] {
        deref().map { $0.value }
    }
}

extension TreeNode {
    private func visit(node: TreeNode, result: inout [MacWindow]) {
        if let node = node as? MacWindow {
            result.append(node)
        }
        for child in node.children.derefTreeNode() {
            visit(node: child, result: &result)
        }
    }

    var allWindowsRecursive: [MacWindow] {
        var result: [MacWindow] = []
        visit(node: self, result: &result)
        return result
    }
}
