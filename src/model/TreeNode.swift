import Foundation

class TreeNode : Equatable {
    private var _children: [TreeNode] = []
    var children: [TreeNode] { _children }
    fileprivate weak var _parent: TreeNode? = nil
    var parent: TreeNode { _parent ?? errorT("TreeNode invariants are broken") }

    init(parent: TreeNode) {
        bindTo(parent: parent)
    }

    fileprivate init() {
    }

    func bindTo(parent newParent: TreeNode) {
        if (newParent === RootTreeNode.instance) {
            return
        }
        let prevParent: TreeNode? = _parent
        if prevParent === newParent {
            return
        }
        prevParent?._children.remove(element: self)
        newParent._children.append(self)
        _parent = newParent
        // Change currentEmptyWorkspace if necessary
        if let window = self as? MacWindow, newParent.workspace == currentEmptyWorkspace {
            let newParentWorkspace = currentEmptyWorkspace
            currentEmptyWorkspace = getOrCreateNextEmptyWorkspace()
            newParentWorkspace.assignedMonitorRect = window.monitorApproximation?.rect ?? allMonitorsRectsUnion
        }
    }

    static func ==(lhs: TreeNode, rhs: TreeNode) -> Bool {
        lhs === rhs
    }
}

class RootTreeNode: TreeNode {
    private override init() {
        super.init()
    }
    static let instance = RootTreeNode()
}

///// Workaround for https://github.com/apple/swift/issues/48596
//class TreeNodeClass {
//    var value: TreeNode
//    init(value: TreeNode) {
//        self.value = value
//    }
//}

//extension WeakArray where T == TreeNodeClass {
//    mutating func derefTreeNode() -> [TreeNode] {
//        deref().map { $0.value }
//    }
//}
