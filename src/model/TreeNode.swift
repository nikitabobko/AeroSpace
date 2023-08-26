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
        if (newParent === NilTreeNode.instance) {
            return
        }
        let prevParent: TreeNode? = _parent
        if prevParent === newParent {
            return
        }
        unbind(parent: prevParent)
        newParent._children.append(self)
        _parent = newParent
        if let window = self as? MacWindow, prevParent?.workspace.lastActiveWindow == window {
            prevParent?.workspace.lastActiveWindow = nil
        }
        // Bind window to empty workspace
        if let window = self as? MacWindow, newParent.workspace == currentEmptyWorkspace {
            let newParentWorkspace = currentEmptyWorkspace
            currentEmptyWorkspace = getOrCreateNextEmptyWorkspace()
            newParentWorkspace.assignedMonitor = window.getTopLeftCorner()?.monitorApproximation
        }
    }

    private func unbind(parent: TreeNode?) {
        guard let parent else { return }
        parent._children.remove(element: self)
        let workspace: Workspace = parent.workspace
        if workspace.isEffectivelyEmpty { // It became empty
            currentEmptyWorkspace = workspace
            currentEmptyWorkspace.assignedMonitor = nil
        }
    }

    func unbindFromParent() {
        unbind(parent: parent)
    }

    static func ==(lhs: TreeNode, rhs: TreeNode) -> Bool {
        lhs === rhs
    }
}

class NilTreeNode: TreeNode {
    private override init() {
        super.init()
    }
    static let instance = NilTreeNode()
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
