import Common

class MacosMinimizedWindowsContainer: TreeNode, NonLeafTreeNodeObject {
    fileprivate init() {
        super.init(parent: NilTreeNode.instance, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }
}

let macosInvisibleWindowsContainer = MacosMinimizedWindowsContainer()
