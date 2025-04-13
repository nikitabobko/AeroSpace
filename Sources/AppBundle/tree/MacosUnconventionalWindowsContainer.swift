import Common

class MacosFullscreenWindowsContainer: TreeNode, NonLeafTreeNodeObject {
    @MainActor
    init(parent: Workspace) {
        super.init(parent: parent, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }
}

/// The container for macOS windows of hidden apps
class MacosHiddenAppsWindowsContainer: TreeNode, NonLeafTreeNodeObject {
    @MainActor
    init(parent: Workspace) {
        super.init(parent: parent, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }
}

@MainActor let macosMinimizedWindowsContainer = MacosMinimizedWindowsContainer()
class MacosMinimizedWindowsContainer: TreeNode, NonLeafTreeNodeObject {
    @MainActor
    fileprivate init() {
        super.init(parent: NilTreeNode.instance, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }
}

@MainActor let macosPopupWindowsContainer = MacosPopupWindowsContainer()
/// The container for macOS objects that are windows from AX perspective but from human perspective they are not even
/// dialogs. E.g. Sonoma (macOS 14) keyboard layout switch
class MacosPopupWindowsContainer: TreeNode, NonLeafTreeNodeObject {
    @MainActor
    fileprivate init() {
        super.init(parent: NilTreeNode.instance, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }
}
