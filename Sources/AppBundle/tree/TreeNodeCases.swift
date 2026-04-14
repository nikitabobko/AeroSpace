import Common

enum TreeNodeCases {
    case window(Window)
    case tilingContainer(TilingContainer)
    case workspace(Workspace)
    case macosMinimizedWindowsContainer(MacosMinimizedWindowsContainer)
    case macosHiddenAppsWindowsContainer(MacosHiddenAppsWindowsContainer)
    case macosFullscreenWindowsContainer(MacosFullscreenWindowsContainer)
    case macosPopupWindowsContainer(MacosPopupWindowsContainer)
}

enum NonLeafTreeNodeCases {
    case tilingContainer(TilingContainer)
    case workspace(Workspace)
    case macosMinimizedWindowsContainer(MacosMinimizedWindowsContainer)
    case macosHiddenAppsWindowsContainer(MacosHiddenAppsWindowsContainer)
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
    case macosHiddenAppsWindowsContainer
    case macosFullscreenWindowsContainer
    case macosPopupWindowsContainer
}

protocol NonLeafTreeNodeObject: TreeNode {}

extension TreeNode {
    var nodeCases: TreeNodeCases {
        switch self {
            case let window as Window: .window(window)
            case let workspace as Workspace: .workspace(workspace)
            case let tilingContainer as TilingContainer: .tilingContainer(tilingContainer)
            case let container as MacosHiddenAppsWindowsContainer: .macosHiddenAppsWindowsContainer(container)
            case let container as MacosMinimizedWindowsContainer: .macosMinimizedWindowsContainer(container)
            case let container as MacosFullscreenWindowsContainer: .macosFullscreenWindowsContainer(container)
            case let container as MacosPopupWindowsContainer: .macosPopupWindowsContainer(container)
            default: die("Unknown tree")
        }
    }

    func tilingTreeNodeCasesOrDie() -> TilingTreeNodeCases {
        switch self {
            case let window as Window: .window(window)
            case let tilingContainer as TilingContainer: .tilingContainer(tilingContainer)
            default: illegalChildParentRelation(child: self, parent: parent)
        }
    }
}

extension NonLeafTreeNodeObject {
    var cases: NonLeafTreeNodeCases {
        switch self {
            case is Window: die("Windows are leaf nodes. They can't have children")
            case let workspace as Workspace: .workspace(workspace)
            case let tilingContainer as TilingContainer: .tilingContainer(tilingContainer)
            case let container as MacosMinimizedWindowsContainer: .macosMinimizedWindowsContainer(container)
            case let container as MacosHiddenAppsWindowsContainer: .macosHiddenAppsWindowsContainer(container)
            case let container as MacosFullscreenWindowsContainer: .macosFullscreenWindowsContainer(container)
            case let container as MacosPopupWindowsContainer: .macosPopupWindowsContainer(container)
            default: die("Unknown tree \(self)")
        }
    }

    var kind: NonLeafTreeNodeKind {
        switch cases {
            case .tilingContainer: .tilingContainer
            case .workspace: .workspace
            case .macosMinimizedWindowsContainer: .macosMinimizedWindowsContainer
            case .macosFullscreenWindowsContainer: .macosFullscreenWindowsContainer
            case .macosHiddenAppsWindowsContainer: .macosHiddenAppsWindowsContainer
            case .macosPopupWindowsContainer: .macosPopupWindowsContainer
        }
    }
}

enum ChildParentRelation: Equatable {
    case floatingWindow
    case macosNativeFullscreenWindow
    case macosNativeHiddenAppWindow
    case macosNativeMinimizedWindow
    case macosPopupWindow
    case tiling(parent: TilingContainer) // todo consider splitting it on 'tiles' and 'accordion'
    case rootTilingContainer

    case shimContainerRelation
}

func getChildParentRelation(child: TreeNode, parent: NonLeafTreeNodeObject) -> ChildParentRelation {
    if let relation = getChildParentRelationOrNil(child: child, parent: parent) {
        return relation
    }
    illegalChildParentRelation(child: child, parent: parent)
}

func illegalChildParentRelation(child: TreeNode, parent: NonLeafTreeNodeObject?) -> Never {
    die("Illegal child-parent relation. Child: \(child), Parent: \((parent ?? child.parent).prettyDescription)")
}

func getChildParentRelationOrNil(child: TreeNode, parent: NonLeafTreeNodeObject) -> ChildParentRelation? {
    return switch (child.nodeCases, parent.cases) {
        case (.workspace, _): nil
        case (.window, .workspace): .floatingWindow

        case (.window, .macosPopupWindowsContainer): .macosPopupWindow
        case (_, .macosPopupWindowsContainer): nil
        case (.macosPopupWindowsContainer, _): nil

        case (.window, .macosMinimizedWindowsContainer): .macosNativeMinimizedWindow
        case (_, .macosMinimizedWindowsContainer): nil
        case (.macosMinimizedWindowsContainer, _): nil

        case (.tilingContainer, .tilingContainer(let container)),
             (.window, .tilingContainer(let container)): .tiling(parent: container)
        case (.tilingContainer, .workspace): .rootTilingContainer

        case (.macosFullscreenWindowsContainer, .workspace): .shimContainerRelation
        case (.window, .macosFullscreenWindowsContainer): .macosNativeFullscreenWindow
        case (.macosFullscreenWindowsContainer, _): nil
        case (_, .macosFullscreenWindowsContainer): nil

        case (.macosHiddenAppsWindowsContainer, .workspace): .shimContainerRelation
        case (.window, .macosHiddenAppsWindowsContainer): .macosNativeHiddenAppWindow
        case (.macosHiddenAppsWindowsContainer, _): nil
        case (_, .macosHiddenAppsWindowsContainer): nil
    }
}
