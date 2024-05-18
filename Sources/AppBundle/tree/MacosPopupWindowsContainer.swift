import Common

/// The container for macOS objects that are windows from AX perspective but from human perspective they are not even
/// dialogs. E.g. Sonoma (macOS 14) keyboard layout switch
class MacosPopupWindowsContainer: TreeNode, NonLeafTreeNodeObject {
    fileprivate init() {
        super.init(parent: NilTreeNode.instance, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }
}

let macosPopupWindowsContainer = MacosPopupWindowsContainer()
