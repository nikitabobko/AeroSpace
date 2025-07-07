import AppKit
import Common

extension TreeNode {
    private func visit(node: TreeNode, result: inout [Window], maxDepth: Int = 100, currentDepth: Int = 0) {
        // Add depth limit to prevent infinite recursion
        guard currentDepth < maxDepth else { return }

        if let node = node as? Window {
            result.append(node)
            return // Early exit for leaf nodes
        }

        // Skip empty containers early
        if node.children.isEmpty { return }

        for child in node.children {
            visit(node: child, result: &result, maxDepth: maxDepth, currentDepth: currentDepth + 1)
        }
    }
    var allLeafWindowsRecursive: [Window] {
        var result: [Window] = []
        result.reserveCapacity(32) // Pre-allocate for typical window count
        visit(node: self, result: &result)
        return result
    }

    var ownIndex: Int? {
        guard let parent else { return nil }
        return parent.children.firstIndex(of: self).orDie()
    }

    var parents: [NonLeafTreeNodeObject] { parent.flatMap { [$0] + $0.parents } ?? [] }
    var parentsWithSelf: [TreeNode] { parent.flatMap { [self] + $0.parentsWithSelf } ?? [self] }

    /// Also see visualWorkspace
    var nodeWorkspace: Workspace? {
        self as? Workspace ?? parent?.nodeWorkspace
    }

    /// Also see: workspace
    @MainActor
    var visualWorkspace: Workspace? { nodeWorkspace ?? nodeMonitor?.activeWorkspace }

    @MainActor
    var nodeMonitor: Monitor? {
        switch self.nodeCases {
            case .workspace(let ws): ws.workspaceMonitor
            case .window: parent?.nodeMonitor
            case .tilingContainer: parent?.nodeMonitor
            case .macosFullscreenWindowsContainer: parent?.nodeMonitor
            case .macosHiddenAppsWindowsContainer: parent?.nodeMonitor
            case .macosMinimizedWindowsContainer, .macosPopupWindowsContainer: nil
        }
    }

    var mostRecentWindowRecursive: Window? {
        // Iterative approach to avoid deep recursion
        var current: TreeNode? = self
        var depth = 0
        let maxDepth = 100

        while let node = current, depth < maxDepth {
            if let window = node as? Window {
                return window
            }
            current = node.mostRecentChild
            depth += 1
        }
        return nil
    }

    var anyLeafWindowRecursive: Window? {
        // Early exit for windows
        if let window = self as? Window {
            return window
        }

        // Early exit for empty containers
        if children.isEmpty { return nil }

        // Use first(where:) for early exit on first found window
        return children.lazy.compactMap { $0.anyLeafWindowRecursive }.first
    }

    // Doesn't contain at least one window
    var isEffectivelyEmpty: Bool {
        // Quick check for windows first
        if self is Window { return false }

        // Quick check for empty containers
        if children.isEmpty { return true }

        // Use lazy evaluation for efficiency
        return !children.lazy.contains { !$0.isEffectivelyEmpty }
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

    /// Returns closest parent that has children in specified direction relative to `self`
    func closestParent(
        hasChildrenInDirection direction: CardinalDirection,
        withLayout layout: Layout?,
    ) -> (parent: TilingContainer, ownIndex: Int)? {
        let innermostChild = parentsWithSelf.first(where: { (node: TreeNode) -> Bool in
            return switch node.parent?.cases {
                // stop searching. We didn't find it, or something went wrong
                case .workspace, nil, .macosMinimizedWindowsContainer,
                     .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer, .macosPopupWindowsContainer:
                    true
                case .tilingContainer(let parent):
                    (layout == nil || parent.layout == layout) &&
                        parent.orientation == direction.orientation &&
                        (node.ownIndex.map { parent.children.indices.contains($0 + direction.focusOffset) } ?? true)
            }
        })
        guard let innermostChild else { return nil }
        switch innermostChild.parent?.cases {
            case .tilingContainer(let parent):
                check(parent.orientation == direction.orientation)
                return innermostChild.ownIndex.map { (parent, $0) }
            case .workspace, nil, .macosMinimizedWindowsContainer,
                 .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer, .macosPopupWindowsContainer:
                return nil
        }
    }
}
