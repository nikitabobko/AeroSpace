import AppKit
import Common

/// Skeleton with real windows substituted for the placeholder slots
struct ResolvedLayoutSkeleton {
    let orientation: Orientation
    let children: [ResolvedLayoutNode]
}

struct ResolvedLayoutRect {
    let width: CGFloat
    let height: CGFloat
}

struct ResolvedLayoutNode {
    let kind: Kind
    let weight: CGFloat? // nil means "no explicit weight". Resolved siblings always get a concrete weight

    enum Kind {
        case window(Window)
        case container(Orientation, children: [ResolvedLayoutNode])
    }
}

private let skeletonReferenceRectKey = TreeNodeUserDataKey<ResolvedLayoutRect>(key: "skeletonReferenceRectKey")
private let skeletonSourceKey = TreeNodeUserDataKey<LayoutSkeleton>(key: "skeletonSourceKey")

extension LayoutSkeleton {
    /// Substitute windows for the placeholder slots. Returns nil if the skeleton resolves to nothing.
    ///
    /// Windows fill the slots in the order the slots appear in the skeleton (the tree order), so the resolved tree
    /// preserves the visual order of the windows. The assignment is therefore a fixed point: it doesn't depend on
    /// the tree it produces, and repeated passes don't fight each other. `others` swallows the remaining windows.
    @MainActor func resolve(windows: [Window]) -> ResolvedLayoutSkeleton? {
        var index = 0
        var passedPlaceholders = 0
        let (node, _) = Self.resolveContainer(
            root,
            windows: windows,
            index: &index,
            passedPlaceholders: &passedPlaceholders,
            totalPlaceholders: root.placeholderCount,
        )
        guard case .container(let orientation, let children)? = node?.kind else { return nil }
        return ResolvedLayoutSkeleton(orientation: orientation, children: children)
    }

    /// The window that the given placeholder slot receives for the given visual order of windows.
    /// Used by `promote` to find the current master (the window in slot `1`).
    @MainActor func windowInPlaceholder(_ number: Int, windows: [Window]) -> Window? {
        var index = 0
        var passedPlaceholders = 0
        let (_, placeholderToWindow) = Self.resolveContainer(
            root,
            windows: windows,
            index: &index,
            passedPlaceholders: &passedPlaceholders,
            totalPlaceholders: root.placeholderCount,
        )
        return placeholderToWindow[number]
    }

    @MainActor private static func resolveContainer(
        _ container: Container,
        windows: [Window],
        index: inout Int,
        passedPlaceholders: inout Int,
        totalPlaceholders: Int,
    ) -> (ResolvedLayoutNode?, [Int: Window]) {
        var kinds: [ResolvedLayoutNode.Kind] = []
        var weights: [CGFloat?] = []
        var placeholderToWindow: [Int: Window] = [:]
        for child in container.children {
            switch child {
                case .placeholder(let number, let weight):
                    if index < windows.count {
                        kinds.append(.window(windows[index]))
                        weights.append(weight.map { CGFloat($0) })
                        placeholderToWindow[number] = windows[index]
                    }
                    index += 1
                    passedPlaceholders += 1
                case .others(let weight):
                    // The windows that remain after every placeholder slot takes one window each
                    let count = max(0, windows.count - (totalPlaceholders - passedPlaceholders) - index)
                    for i in 0 ..< count {
                        kinds.append(.window(windows[index + i]))
                        weights.append(weight.map { CGFloat($0) })
                    }
                    index += count
                case .container(let container):
                    let (node, innerPlaceholderToWindow) = Self.resolveContainer(
                        container,
                        windows: windows,
                        index: &index,
                        passedPlaceholders: &passedPlaceholders,
                        totalPlaceholders: totalPlaceholders,
                    )
                    placeholderToWindow.merge(innerPlaceholderToWindow) { _, new in new }
                    if let node {
                        kinds.append(node.kind)
                        weights.append(node.weight)
                    }
            }
        }
        let node: ResolvedLayoutNode? = switch kinds.count {
            case 0: nil
            // Collapse containers with a single child. The child takes the container's weight: the child's own
            // weight refers to the collapsed axis and is dropped
            case 1: ResolvedLayoutNode(kind: kinds[0], weight: container.weight.map { CGFloat($0) })
            default: ResolvedLayoutNode(
                    kind: .container(container.orientation, children: zip(kinds, shareWeights(weights))
                        .map { ResolvedLayoutNode(kind: $0.0, weight: $0.1) }),
                    weight: container.weight.map { CGFloat($0) },
                )
        }
        return (node, placeholderToWindow)
    }

    /// Explicit weights are the shares of the parent's axis. The rest of the axis is split equally among the siblings
    /// that don't have an explicit weight
    private static func shareWeights(_ weights: [CGFloat?]) -> [CGFloat] {
        switch weights.count {
            case 0: return []
            case 1: return [1]
            default: break
        }
        guard weights.contains(where: { $0 == nil }) else {
            // Every sibling has an explicit weight. Weights are relative, layoutTiles normalizes the sum
            return weights.compactMap { $0 }
        }
        let unspecifiedCount = weights.count(where: { $0 == nil })
        let specifiedSum = weights.compactMap { $0 }.reduce(0, +)
        let share = (1 - specifiedSum) / CGFloat(unspecifiedCount)
        return weights.map { $0 ?? share }
    }
}

extension TilingContainer {
    /// Reshape the workspace into the requested skeleton. Idempotent: the tree is rebuilt only when the current shape
    /// doesn't match the skeleton, or when the monitor geometry changed since the last rebuild. That way manual
    /// window resizing isn't reset on every refresh.
    @MainActor func normalizeLayoutSkeleton(_ skeleton: LayoutSkeleton) {
        guard isRootContainer, layout == .tiles else { return }
        let windows = tilingWindowsInVisualOrder()
        guard !windows.isEmpty, let resolved = skeleton.resolve(windows: windows) else { return }
        forceOrientation(resolved.orientation)
        let rect = nodeWorkspace.orDie().workspaceMonitorInfo.visibleRectPaddedByOuterGaps
        // Weights are pixels of the parent's axis (see bindResolved). The tree must be rebuilt when the skeleton
        // changed since the last rebuild (e.g. the config was reloaded with different weights), or when the monitor
        // geometry changed: the weights then still belong to the old monitor, and the additive normalization of
        // layoutTiles would distort the shares. Comparing the stored reference rect instead of the sum of the
        // weights keeps manual resizing intact: a resize changes the weights but neither the skeleton, the shape
        // nor the monitor, so the tree isn't rebuilt.
        let reference = getUserData(key: skeletonReferenceRectKey.self)
        let source = getUserData(key: skeletonSourceKey.self)
        if matchesResolved(resolved.children),
           source == skeleton,
           let reference, reference.width == rect.width, reference.height == rect.height { return }
        rebuildResolved(resolved.children, in: ResolvedLayoutRect(width: rect.width, height: rect.height))
        putUserData(key: skeletonReferenceRectKey.self, data: ResolvedLayoutRect(width: rect.width, height: rect.height))
        putUserData(key: skeletonSourceKey.self, data: skeleton)
    }

    @MainActor func tilingWindowsInVisualOrder() -> [Window] {
        var result: [Window] = []
        func visit(_ node: TreeNode) {
            switch node.tilingTreeNodeCasesOrDie() {
                case .window(let window): result.append(window)
                case .tilingContainer(let container): container.inhabitedChildren.forEach(visit)
            }
        }
        inhabitedChildren.forEach(visit)
        return result
    }

    @MainActor private func matchesResolved(_ nodes: [ResolvedLayoutNode]) -> Bool {
        guard children.count == nodes.count else { return false }
        for (child, node) in zip(children, nodes) {
            switch node.kind {
                case .window(let window):
                    if child !== window { return false }
                case .container(let orientation, let nodes):
                    guard let container = child as? TilingContainer,
                          container.layout == .tiles,
                          container.orientation == orientation,
                          container.matchesResolved(nodes) else { return false }
            }
        }
        return true
    }

    @MainActor private func rebuildResolved(_ nodes: [ResolvedLayoutNode], in rect: ResolvedLayoutRect) {
        let mostRecentWindow = mostRecentWindowRecursive
        let oldChildren = children
        for child in oldChildren {
            child.unbindFromParent()
        }
        bindResolved(nodes, in: rect)
        mostRecentWindow?.markAsMostRecentChild()
    }

    /// Weights are pixels of the parent's axis, not fractions. `layoutTiles` normalizes the weights by adding an equal
    /// delta to each child, so fractions would be flattened to an equal split on the first layout pass
    @MainActor private func bindResolved(_ nodes: [ResolvedLayoutNode], in rect: ResolvedLayoutRect) {
        let axisLength = orientation == .h ? rect.width : rect.height
        for node in nodes {
            let share = node.weight ?? 1
            let weight = share * axisLength
            switch node.kind {
                case .window(let window):
                    window.bind(to: self, adaptiveWeight: weight, index: INDEX_BIND_LAST)
                case .container(let orientation, let children):
                    let container = TilingContainer(parent: self, adaptiveWeight: weight, orientation, .tiles, index: INDEX_BIND_LAST)
                    let childRect = self.orientation == .h
                        ? ResolvedLayoutRect(width: rect.width * share, height: rect.height)
                        : ResolvedLayoutRect(width: rect.width, height: rect.height * share)
                    container.bindResolved(children, in: childRect)
            }
        }
    }
}
