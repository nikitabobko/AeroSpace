import Common

enum TreeNodeKind {
    case window(Window)
    case tilingContainer(TilingContainer)
    case workspace(Workspace)
}

enum NonLeafTreeNodeKind {
    case tilingContainer(TilingContainer)
    case workspace(Workspace)
}

protocol NonLeafTreeNode: TreeNode {}

extension TreeNode {
    var genericKind: TreeNodeKind {
        if let window = self as? Window {
            return .window(window)
        } else if let workspace = self as? Workspace {
            return .workspace(workspace)
        } else if let tilingContainer = self as? TilingContainer {
            return .tilingContainer(tilingContainer)
        } else {
            error("Unknown tree")
        }
    }
}

extension NonLeafTreeNode {
    var kind: NonLeafTreeNodeKind {
        if self is Window {
            windowsCantHaveChildren()
        } else if let workspace = self as? Workspace {
            return .workspace(workspace)
        } else if let tilingContainer = self as? TilingContainer {
            return .tilingContainer(tilingContainer)
        } else {
            error("Unknown tree")
        }
    }
}
