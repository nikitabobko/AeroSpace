import Common

enum TreeNodeCases {
    case window(Window)
    case tilingContainer(TilingContainer)
    case workspace(Workspace)
    case monitor(Monitor)
    case workspacesContainer(WorkspacesContainer)
    case macosMinimizedWindowsContainer(MacosMinimizedWindowsContainer)
    case macosHiddenAppsWindowsContainer(MacosHiddenAppsWindowsContainer)
    case macosFullscreenWindowsContainer(MacosFullscreenWindowsContainer)
    case macosPopupWindowsContainer(MacosPopupWindowsContainer)
    case floatingWindowsContainer(FloatingWindowsContainer)
}

enum NonLeafTreeNodeCases {
    case tilingContainer(TilingContainer)
    case workspace(Workspace)
    case monitor(Monitor)
    case workspacesContainer(WorkspacesContainer)
    case macosMinimizedWindowsContainer(MacosMinimizedWindowsContainer)
    case macosHiddenAppsWindowsContainer(MacosHiddenAppsWindowsContainer)
    case macosFullscreenWindowsContainer(MacosFullscreenWindowsContainer)
    case macosPopupWindowsContainer(MacosPopupWindowsContainer)
    case floatingWindowsContainer(FloatingWindowsContainer)
}

enum TilingTreeNodeCases {
    case window(Window)
    case tilingContainer(TilingContainer)

    var isInhabited: Bool {
        switch self {
            case .window(let it): it.lifeStatus.isInhabited
            case .tilingContainer(let it): it.lifeStatus.isInhabited
        }
    }
}

enum WindowParentCases {
    case tilingContainer(TilingContainer)
    case macosMinimizedWindowsContainer(MacosMinimizedWindowsContainer)
    case macosHiddenAppsWindowsContainer(MacosHiddenAppsWindowsContainer)
    case macosFullscreenWindowsContainer(MacosFullscreenWindowsContainer)
    case macosPopupWindowsContainer(MacosPopupWindowsContainer)
    case floatingWindowsContainer(FloatingWindowsContainer)

    var kind: Kind {
        switch self {
            case .tilingContainer: .tilingContainer
            case .macosMinimizedWindowsContainer: .macosMinimizedWindowsContainer
            case .macosHiddenAppsWindowsContainer: .macosHiddenAppsWindowsContainer
            case .macosFullscreenWindowsContainer: .macosFullscreenWindowsContainer
            case .macosPopupWindowsContainer: .macosPopupWindowsContainer
            case .floatingWindowsContainer: .floatingWindowsContainer
        }
    }

    enum Kind {
        case tilingContainer
        case macosMinimizedWindowsContainer
        case macosHiddenAppsWindowsContainer
        case macosFullscreenWindowsContainer
        case macosPopupWindowsContainer
        case floatingWindowsContainer
    }
}

enum TilingContainerParentCases {
    case unbound
    case tilingContainer(TilingContainer)
    case workspace(Workspace)
}

enum ConventionalWindowParentCases {
    case tilingContainer(TilingContainer)
    case floatingWindowsContainer(FloatingWindowsContainer)

    var tilingContainerOrNil: TilingContainer? {
        switch self {
            case .tilingContainer(let it): it
            default: nil
        }
    }

    var floatingWindowsContainerOrNil: FloatingWindowsContainer? {
        switch self {
            case .floatingWindowsContainer(let it): it
            default: nil
        }
    }
}

protocol NonLeafTreeNodeObject: TreeNode {}

extension Window {
    var windowParentCases: WindowParentCases? {
        guard let parent else { return nil }
        return switch parent.cases {
            case .floatingWindowsContainer(let it): .floatingWindowsContainer(it)
            case .macosFullscreenWindowsContainer(let it): .macosFullscreenWindowsContainer(it)
            case .macosHiddenAppsWindowsContainer(let it): .macosHiddenAppsWindowsContainer(it)
            case .macosMinimizedWindowsContainer(let it): .macosMinimizedWindowsContainer(it)
            case .macosPopupWindowsContainer(let it): .macosPopupWindowsContainer(it)
            case .tilingContainer(let it): .tilingContainer(it)
            case .monitor: dieT("Monitor can't have direct Window children")
            case .workspacesContainer: dieT("WorkspacesContainer can't have direct Window children")
            case .workspace: dieT("Workspace can't have direct Window children")
        }
    }
}

extension TilingContainer {
    var tilingContainerParentCases: TilingContainerParentCases {
        guard let parent else { return .unbound }
        return switch parent.cases {
            case .tilingContainer(let it): .tilingContainer(it)
            case .workspace(let it): .workspace(it)
            case .monitor: dieT("Monitor can't be TilingContainer's parent")
            case .workspacesContainer: dieT("WorkspacesContainer can't be TilingContainer's parent")
            case .floatingWindowsContainer: dieT("floatingWindowsContainer can't be TilingContainer's parent")
            case .macosFullscreenWindowsContainer: dieT("macosFullscreenWindowsContainer can't be TilingContainer's parent")
            case .macosHiddenAppsWindowsContainer: dieT("macosHiddenAppsWindowsContainer can't be TilingContainer's parent")
            case .macosMinimizedWindowsContainer: dieT("macosMinimizedWindowsContainer can't be TilingContainer's parent")
            case .macosPopupWindowsContainer: dieT("macosPopupWindowsContainer can't be TilingContainer's parent")
        }
    }
}

extension TreeNode {
    var nodeCases: TreeNodeCases {
        switch self {
            case let it as Window: .window(it)
            case let it as Workspace: .workspace(it)
            case let it as Monitor: .monitor(it)
            case let it as WorkspacesContainer: .workspacesContainer(it)
            case let it as TilingContainer: .tilingContainer(it)
            case let it as MacosHiddenAppsWindowsContainer: .macosHiddenAppsWindowsContainer(it)
            case let it as MacosMinimizedWindowsContainer: .macosMinimizedWindowsContainer(it)
            case let it as MacosFullscreenWindowsContainer: .macosFullscreenWindowsContainer(it)
            case let it as MacosPopupWindowsContainer: .macosPopupWindowsContainer(it)
            case let it as FloatingWindowsContainer: .floatingWindowsContainer(it)
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
            case let it as Workspace: .workspace(it)
            case let it as Monitor: .monitor(it)
            case let it as WorkspacesContainer: .workspacesContainer(it)
            case let it as TilingContainer: .tilingContainer(it)
            case let it as MacosMinimizedWindowsContainer: .macosMinimizedWindowsContainer(it)
            case let it as MacosHiddenAppsWindowsContainer: .macosHiddenAppsWindowsContainer(it)
            case let it as MacosFullscreenWindowsContainer: .macosFullscreenWindowsContainer(it)
            case let it as MacosPopupWindowsContainer: .macosPopupWindowsContainer(it)
            case let it as FloatingWindowsContainer: .floatingWindowsContainer(it)
            default: die("Unknown tree \(self)")
        }
    }
}

enum ChildParentRelation: Equatable { // todo: do I need it?
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

func illegalChildParentRelation(child: TreeNode, parent: NonLeafTreeNodeObject?, fileId: MyFileId = #myFileId) -> Never {
    let msg = "Illegal child-parent relation. Child: \(child), Parent: \((parent ?? child.parent).prettyDescription)"
    die(msg, fileId: fileId)
}

func getChildParentRelationOrNil(child: TreeNode, parent: NonLeafTreeNodeObject) -> ChildParentRelation? {
    return switch (child.nodeCases, parent.cases) {
        case (.monitor, _): nil

        case (.workspacesContainer, .monitor): .shimContainerRelation
        case (.workspacesContainer, _): nil
        case (_, .monitor): nil

        case (.workspace, .workspacesContainer): .shimContainerRelation
        case (.workspace, _): nil
        case (.tilingContainer, .workspacesContainer): nil
        case (.window, .workspacesContainer): nil
        case (.window, .workspace): nil

        case (.window, .macosPopupWindowsContainer): .macosPopupWindow
        case (_, .macosPopupWindowsContainer): nil
        case (.macosPopupWindowsContainer, _): nil

        case (.window, .macosMinimizedWindowsContainer): .macosNativeMinimizedWindow
        case (_, .macosMinimizedWindowsContainer): nil
        case (.macosMinimizedWindowsContainer, _): nil

        case (.tilingContainer, .tilingContainer(let container)),
             (.window, .tilingContainer(let container)): .tiling(parent: container)
        case (.tilingContainer, .workspace): .rootTilingContainer

        case (.floatingWindowsContainer, .workspace): .shimContainerRelation
        case (.window, .floatingWindowsContainer): .floatingWindow
        case (.floatingWindowsContainer, _): nil
        case (_, .floatingWindowsContainer): nil

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
