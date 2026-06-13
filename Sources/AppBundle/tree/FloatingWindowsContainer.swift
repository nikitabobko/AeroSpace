final class FloatingWindowsContainer: TreeNode, NonLeafTreeNodeObject {
    @MainActor
    init(parent: Workspace) {
        super.init(parent: parent, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }
}
