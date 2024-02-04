import Common

enum TreeNodeCases {
    case window(Window)
    case tilingContainer(TilingContainer)
    case workspace(Workspace)
    case macosInvisibleWindowsContainer(MacosInvisibleWindowsContainer)
}

enum NonLeafTreeNodeCases {
    case tilingContainer(TilingContainer)
    case workspace(Workspace)
    case macosInvisibleWindowsContainer(MacosInvisibleWindowsContainer)
}

enum NonRootTreeNodeCases {
    case window(Window)
    case tilingContainer(TilingContainer)
}

enum NonLeafTreeNodeKind: Equatable {
    case tilingContainer
    case workspace
    case macosInvisibleWindowsContainer
}

protocol NonLeafTreeNodeObject: TreeNode {}

extension TreeNode {
    var nodeCases: TreeNodeCases {
        if let window = self as? Window {
            return .window(window)
        } else if let workspace = self as? Workspace {
            return .workspace(workspace)
        } else if let tilingContainer = self as? TilingContainer {
            return .tilingContainer(tilingContainer)
        } else if let container = self as? MacosInvisibleWindowsContainer {
            return .macosInvisibleWindowsContainer(container)
        } else {
            error("Unknown tree")
        }
    }

    func nonRootTreeNodeCasesOrThrow() -> NonRootTreeNodeCases {
        if let window = self as? Window {
            return .window(window)
        } else if let tilingContainer = self as? TilingContainer {
            return .tilingContainer(tilingContainer)
        } else {
            illegalChildParentRelation(child: self, parent: parent)
        }
    }
}

extension NonLeafTreeNodeObject {
    var cases: NonLeafTreeNodeCases {
        if self is Window {
            windowsCantHaveChildren()
        } else if let workspace = self as? Workspace {
            return .workspace(workspace)
        } else if let tilingContainer = self as? TilingContainer {
            return .tilingContainer(tilingContainer)
        } else if let container = self as? MacosInvisibleWindowsContainer {
            return .macosInvisibleWindowsContainer(container)
        } else {
            error("Unknown tree")
        }
    }

    var kind: NonLeafTreeNodeKind {
        switch cases {
        case .tilingContainer:
            return .tilingContainer
        case .workspace:
            return .workspace
        case .macosInvisibleWindowsContainer:
            return .macosInvisibleWindowsContainer
        }
    }
}

enum ChildParentRelation: Equatable {
    case floatingWindow
    case macosNativeFullscreenWindow
    case macosNativeInvisibleWindow
    case tiling(parent: TilingContainer) // todo consider splitting it on 'tiles' and 'accordion'
    case rootTilingContainer
}

func getChildParentRelation(child: TreeNode, parent: NonLeafTreeNodeObject) -> ChildParentRelation {
    if let relation = getChildParentRelationOrNil(child: child, parent: parent) {
        return relation
    }
    illegalChildParentRelation(child: child, parent: parent)
}

func illegalChildParentRelation(child: TreeNode, parent: NonLeafTreeNodeObject?) -> Never {
    error("Illegal child-parent relation. Child: \(child), Parent: \((parent ?? child.parent).optionalToPrettyString())")
}

func getChildParentRelationOrNil(child: TreeNode, parent: NonLeafTreeNodeObject) -> ChildParentRelation? {
    switch (child.nodeCases, parent.cases) {
    case (.workspace, _):
        return nil
    case (.window(let window), .workspace):
        return window.isMacosFullscreen ? .macosNativeFullscreenWindow : .floatingWindow
    case (.window, .macosInvisibleWindowsContainer):
        return .macosNativeInvisibleWindow
    case (_, .macosInvisibleWindowsContainer):
        return nil
    case (.tilingContainer, .tilingContainer(let container)),
         (.window, .tilingContainer(let container)):
        return .tiling(parent: container)
    case (.tilingContainer, .workspace):
        return .rootTilingContainer
    case (.macosInvisibleWindowsContainer, _):
        return nil
    }
}
