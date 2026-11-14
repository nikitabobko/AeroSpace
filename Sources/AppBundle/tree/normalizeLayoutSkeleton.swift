import AppKit
import Common

/// Skeleton with real windows substituted for placeholders
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

extension LayoutSkeleton {
    /// Substitute windows for placeholders. Returns nil if the skeleton resolves to nothing
    @MainActor func resolve(windows: [Window]) -> ResolvedLayoutSkeleton? {
        let placeholders = root.placeholdersSorted
        var placeholderToWindow: [Int: Window] = [:]
        for (index, number) in placeholders.enumerated() where index < windows.count {
            placeholderToWindow[number] = windows[index]
        }
        let others = Array(windows.dropFirst(min(placeholders.count, windows.count)))
        guard let node = Self.resolveContainer(root, placeholderToWindow, others),
              case .container(let orientation, let children) = node.kind else { return nil }
        return ResolvedLayoutSkeleton(orientation: orientation, children: children)
    }

    @MainActor private static func resolveContainer(
        _ container: Container,
        _ placeholders: [Int: Window],
        _ others: [Window],
    ) -> ResolvedLayoutNode? {
        var kinds: [ResolvedLayoutNode.Kind] = []
        var weights: [CGFloat?] = []
        for child in container.children {
            switch child {
                case .placeholder(let number, let weight):
                    if let window = placeholders[number] {
                        kinds.append(.window(window))
                        weights.append(weight.map { CGFloat($0) })
                    }
                case .others(let weight):
                    for window in others {
                        kinds.append(.window(window))
                        weights.append(weight.map { CGFloat($0) })
                    }
                case .container(let container):
                    if let node = resolveContainer(container, placeholders, others) {
                        kinds.append(node.kind)
                        weights.append(node.weight)
                    }
            }
        }
        return switch kinds.count {
            case 0: nil
            case 1: ResolvedLayoutNode(kind: kinds[0], weight: weights[0]) // Collapse containers with a single child
            default: ResolvedLayoutNode(
                    kind: .container(container.orientation, children: zip(kinds, shareWeights(weights))
                        .map { ResolvedLayoutNode(kind: $0.0, weight: $0.1) }),
                    weight: container.weight.map { CGFloat($0) },
                )
        }
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
            return weights.map { $0 ?? 1 } // Every sibling has an explicit weight. Weights are relative
        }
        let unspecifiedCount = weights.count(where: { $0 == nil })
        if unspecifiedCount == 0 {
            return weights.map { $0 ?? 1 } // All the siblings have an explicit weight. Weights are relative
        }
        let specifiedSum = weights.compactMap { $0 }.reduce(0, +)
        let share = (1 - specifiedSum) / CGFloat(unspecifiedCount)
        return weights.map { $0 ?? share }
    }
}

extension TilingContainer {
    /// Reshape the workspace into the requested skeleton. Idempotent: the tree is rebuilt only when the current shape
    /// doesn't match the skeleton. That way manual window resizing isn't reset on every refresh
    @MainActor func normalizeLayoutSkeleton(_ skeleton: LayoutSkeleton) {
        guard isRootContainer, layout == .tiles else { return }
        let windows = tilingWindowsInVisualOrder()
        guard !windows.isEmpty, let resolved = skeleton.resolve(windows: windows) else { return }
        forceOrientation(resolved.orientation)
        let rect = nodeWorkspace.orDie().workspaceMonitorInfo.visibleRectPaddedByOuterGaps
        // Weights are pixels of the parent's axis (see bindResolved). When the monitor geometry changes, the weights
        // still belong to the old monitor, and the additive normalization of layoutTiles would distort the shares.
        // So the tree must also be rebuilt when the weights don't sum up to the current monitor's axis.
        // The tolerance absorbs the `height - 1` quirk of layoutWorkspace and the floating point noise of layoutTiles
        let axisLength = orientation == .h ? rect.width : rect.height
        let weightsMatchMonitor = abs(children.sumOfDouble { $0.getWeight(orientation) } - axisLength) < 2
        guard !matchesResolved(resolved.children) || !weightsMatchMonitor else { return }
        rebuildResolved(resolved.children, in: ResolvedLayoutRect(width: rect.width, height: rect.height))
    }

    @MainActor private func tilingWindowsInVisualOrder() -> [Window] {
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
