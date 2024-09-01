import Common

enum TreeNodeCases {
    case window(Window)
    case tilingContainer(TilingContainer)
    case workspace(Workspace)
    case macosMinimizedWindowsContainer(MacosMinimizedWindowsContainer)
    case macosFullscreenWindowsContainer(MacosFullscreenWindowsContainer)
    case macosPopupWindowsContainer(MacosPopupWindowsContainer)
}

enum NonLeafTreeNodeCases {
    case tilingContainer(TilingContainer)
    case workspace(Workspace)
    case macosMinimizedWindowsContainer(MacosMinimizedWindowsContainer)
    case macosFullscreenWindowsContainer(MacosFullscreenWindowsContainer)
    case macosPopupWindowsContainer(MacosPopupWindowsContainer)
}

enum TilingTreeNodeCases {
    case window(Window)
    case tilingContainer(TilingContainer)
}

enum NonLeafTreeNodeKind: Equatable {
    case tilingContainer
    case workspace
    case macosMinimizedWindowsContainer
    case macosFullscreenWindowsContainer
    case macosPopupWindowsContainer
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
        } else if let container = self as? MacosMinimizedWindowsContainer {
            return .macosMinimizedWindowsContainer(container)
        } else if let container = self as? MacosFullscreenWindowsContainer {
            return .macosFullscreenWindowsContainer(container)
        } else if let container = self as? MacosPopupWindowsContainer {
            return .macosPopupWindowsContainer(container)
        } else {
            error("Unknown tree")
        }
    }

    func tilingTreeNodeCasesOrThrow() -> TilingTreeNodeCases {
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
            error("Windows are leaf nodes. They can't have children")
        } else if let workspace = self as? Workspace {
            return .workspace(workspace)
        } else if let tilingContainer = self as? TilingContainer {
            return .tilingContainer(tilingContainer)
        } else if let container = self as? MacosMinimizedWindowsContainer {
            return .macosMinimizedWindowsContainer(container)
        } else if let container = self as? MacosFullscreenWindowsContainer {
            return .macosFullscreenWindowsContainer(container)
        } else if let container = self as? MacosPopupWindowsContainer {
            return .macosPopupWindowsContainer(container)
        } else {
            error("Unknown tree \(self)")
        }
    }

    var kind: NonLeafTreeNodeKind {
        return switch cases {
            case .tilingContainer: .tilingContainer
            case .workspace: .workspace
            case .macosMinimizedWindowsContainer: .macosMinimizedWindowsContainer
            case .macosFullscreenWindowsContainer: .macosFullscreenWindowsContainer
            case .macosPopupWindowsContainer: .macosPopupWindowsContainer
        }
    }
}

enum ChildParentRelation: Equatable {
    case floatingWindow
    case macosNativeFullscreenWindow
    case macosNativeFullscreenStubContainer
    case macosNativeMinimizedWindow
    case macosPopupWindow
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
    return switch (child.nodeCases, parent.cases) {
        case (.workspace, _): nil
        case (.window, .workspace): .floatingWindow
        case (.window, .macosMinimizedWindowsContainer): .macosNativeMinimizedWindow
        case (.window, .macosPopupWindowsContainer): .macosPopupWindow
        case (_, .macosMinimizedWindowsContainer): nil
        case (_, .macosPopupWindowsContainer): nil
        case (.tilingContainer, .tilingContainer(let container)),
             (.window, .tilingContainer(let container)): .tiling(parent: container)
        case (.tilingContainer, .workspace): .rootTilingContainer
        case (.macosMinimizedWindowsContainer, _): nil
        case (.macosPopupWindowsContainer, _): nil
        case (.macosFullscreenWindowsContainer, .workspace): .macosNativeFullscreenStubContainer
        case (.macosFullscreenWindowsContainer, _): nil
        case (.window, .macosFullscreenWindowsContainer): .macosNativeFullscreenWindow
        case (_, .macosFullscreenWindowsContainer): nil
    }
}
