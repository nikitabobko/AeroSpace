import Common

/// The container for macOS minimized windows and windows of hidden applications
class MacosInvisibleWindowsContainer: TreeNode, NonLeafTreeNodeObject {
    fileprivate init() {
        super.init(parent: NilTreeNode.instance, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }
}

let macosInvisibleWindowsContainer = MacosInvisibleWindowsContainer()
