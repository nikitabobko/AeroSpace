import AppKit
import Common

extension TreeNode {
    private func visit(node: TreeNode, result: inout [Window]) {
        if let node = node as? Window {
            result.append(node)
        }
        for child in node.children {
            visit(node: child, result: &result)
        }
    }
    var allLeafWindowsRecursive: [Window] {
        var result: [Window] = []
        visit(node: self, result: &result)
        return result
    }

    var allInhabitedLeafWindowsRecursive: [Window] {
        allLeafWindowsRecursive.filter { $0.lifeStatus.isInhabited }
    }

    func ownIndex(in scope: HabitationScope) -> Int? {
        guard let parent else { return nil }
        return switch scope {
            case .all: parent.children.firstIndex(of: self)
            case .inhabitedOnly: parent.inhabitedChildren.firstIndex(of: self)
        }
    }

    func nearestAliveTilingParent() -> (parent: TilingContainer, index: Int)? {
        var node: TreeNode = self
        while true {
            guard let parent = node.parent as? TilingContainer else { return nil }
            switch parent.lifeStatus {
                case .alive: return node.ownIndex(in: .all).map { (parent, $0) }
                case .mustBeFlattened, .deadOrInvisible: node = parent
            }
        }
    }

    var parents: [NonLeafTreeNodeObject] { parent.flatMap { [$0] + $0.parents } ?? [] }
    var parentsWithSelf: [TreeNode] { parent.flatMap { [self] + $0.parentsWithSelf } ?? [self] }

    /// Also see visualWorkspace
    var nodeWorkspace: Workspace? {
        self as? Workspace ?? parent?.nodeWorkspace
    }

    /// Also see: nodeWorkspace
    @MainActor var visualWorkspace: Workspace? { nodeWorkspace ?? nodeMonitorInfo?.visibleWorkspace }

    @MainActor var nodeMonitorInfo: MonitorInfo? {
        switch self.nodeCases {
            case .monitor(let it): it.info
            case .window,
                 .workspace,
                 .workspacesContainer,
                 .tilingContainer,
                 .macosFullscreenWindowsContainer,
                 .macosHiddenAppsWindowsContainer,
                 .floatingWindowsContainer: parent?.nodeMonitorInfo
            case .macosMinimizedWindowsContainer, .macosPopupWindowsContainer: nil
        }
    }

    var mostRecentWindowRecursive: Window? {
        self as? Window ?? mostRecentChild?.mostRecentWindowRecursive
    }

    var anyLeafWindowRecursive: Window? {
        if let window = self as? Window {
            return window
        }
        for child in children {
            if let window = child.anyLeafWindowRecursive {
                return window
            }
        }
        return nil
    }

    // Doesn't contain at least one window
    var isEffectivelyEmpty: Bool {
        anyLeafWindowRecursive == nil
    }

    @MainActor
    var hWeight: CGFloat {
        get { getWeight(.h) }
        set { setWeight(.h, newValue) }
    }

    @MainActor
    var vWeight: CGFloat {
        get { getWeight(.v) }
        set { setWeight(.v, newValue) }
    }

    /// Returns closest parent that has visible (non-tombstone) children in the specified direction relative to `self`
    ///
    /// `neighborIndex` is the index of the closest visible child of `parent` in the specified direction
    func closestParent(
        hasInhabitedChildrenInDirection direction: CardinalDirection,
        withLayout layout: Layout?,
    ) -> (parent: TilingContainer, ownIndex: Int, neighborIndex: Int)? {
        for node in parentsWithSelf {
            switch node.parent?.cases {
                // stop searching. We didn't find it, or something went wrong
                case .workspace, nil, .macosMinimizedWindowsContainer,
                     .floatingWindowsContainer,
                     .macosFullscreenWindowsContainer,
                     .macosHiddenAppsWindowsContainer,
                     .monitor,
                     .workspacesContainer,
                     .macosPopupWindowsContainer:
                    return nil
                case .tilingContainer(let parent):
                    if (layout == nil || parent.layout == layout) && parent.orientation == direction.orientation {
                        guard let ownIndex = node.ownIndex(in: .all) else { return nil }
                        if let neighborIndex = parent.inhabitedSiblingIndex(of: ownIndex, in: direction) {
                            return (parent, ownIndex, neighborIndex)
                        }
                    }
            }
        }
        return nil
    }
}

extension TilingContainer {
    func inhabitedSiblingIndex(of ownIndex: Int, in direction: CardinalDirection) -> Int? {
        let candidates = direction.isPositive
            ? stride(from: ownIndex + 1, to: children.count, by: 1)
            : stride(from: ownIndex - 1, to: -1, by: -1)
        return candidates.first(where: { children[$0].tilingTreeNodeCasesOrDie().isInhabited })
    }
}

extension TilingTreeNodeCases {
    func resolvedThroughMustBeFlattenedRecursive() -> TilingTreeNodeCases {
        switch self {
            case .window:
                self
            case .tilingContainer(let container):
                switch container.lifeStatus {
                    case .alive:
                        self
                    case .mustBeFlattened:
                        container.mostRecentInhabitedChild.orDie("Inhabited containers must have at least one inhabited child")
                            .tilingTreeNodeCasesOrDie()
                            .resolvedThroughMustBeFlattenedRecursive()
                    case .deadOrInvisible:
                        die("Tombstone containers are skipped by the callers")
                }
        }
    }
}

enum HabitationScope {
    case all
    case inhabitedOnly
}
