import Common

/// The container for macOS windows of hidden apps
class MacosHiddenAppsWindowsContainer: TreeNode, NonLeafTreeNodeObject {
    init(parent: Workspace) {
        super.init(parent: parent, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }
}
