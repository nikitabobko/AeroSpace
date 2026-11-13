import AppKit
import Common

// periphery:ignore - The sticky case is used after the sticky-window branch is rebased on this globalFocus projection.
enum FocusCandidateRole: Equatable {
    case tiling
    case floating
    case sticky
}

@MainActor
private struct FocusContext {
    let windowId: OpaqueWindowId?
    let workspaceName: String
    let monitorId: Int

    static var current: FocusContext {
        FocusContext(
            windowId: globalFocus.windowOrNil?.windowId,
            workspaceName: globalFocus.workspace.name,
            monitorId: globalFocus.workspace.workspaceMonitorInfo.monitorId_oneBased ?? 0,
        )
    }

    func matchesCurrent() -> Bool {
        let current = FocusContext.current
        return windowId == current.windowId &&
            workspaceName == current.workspaceName &&
            monitorId == current.monitorId
    }
}

@MainActor
private final class FocusTreeNode {
    let window: Window?
    let role: FocusCandidateRole?
    let orientation: Orientation?
    weak var parent: FocusTreeNode?
    var children: [FocusTreeNode] = []
    private weak var explicitMostRecentChild: FocusTreeNode?

    init(window: Window, role: FocusCandidateRole) {
        self.window = window
        self.role = role
        orientation = nil
    }

    init(container: TilingContainer) {
        window = nil
        role = nil
        orientation = container.orientation
    }

    var ownIndex: Int? {
        guard let parent else { return nil }
        return parent.children.firstIndex { $0 === self }
    }

    var parentsWithSelf: [FocusTreeNode] {
        parent.flatMap { [self] + $0.parentsWithSelf } ?? [self]
    }

    var mostRecentChild: FocusTreeNode? { explicitMostRecentChild ?? children.last }

    func append(_ child: FocusTreeNode) {
        child.parent = self
        children.append(child)
    }

    func insert(_ child: FocusTreeNode, at index: Int) {
        child.parent = self
        children.insert(child, at: index != INDEX_BIND_LAST ? index : children.count)
        child.markAsMostRecentChild()
    }

    func setMostRecentChild(_ child: FocusTreeNode?) {
        explicitMostRecentChild = child
    }

    func markAsMostRecentChild() {
        guard let parent else { return }
        parent.explicitMostRecentChild = self
        parent.markAsMostRecentChild()
    }

    func allLeafWindowsRecursive() -> [Window] {
        if let window {
            check(role != nil)
            return [window]
        }
        return children.flatMap { $0.allLeafWindowsRecursive() }
    }

    func closestParent(hasChildrenInDirection direction: CardinalDirection) -> (parent: FocusTreeNode, ownIndex: Int)? {
        let innermostChild = parentsWithSelf.first { node in
            guard let parent = node.parent else { return true }
            guard parent.orientation == direction.orientation else { return false }
            return node.ownIndex.map { parent.children.indices.contains($0 + direction.focusOffset) } ?? true
        }
        guard let innermostChild, let parent = innermostChild.parent, parent.orientation == direction.orientation else {
            return nil
        }
        return innermostChild.ownIndex.map { (parent, $0) }
    }

    func findLeafWindowRecursive(snappedTo direction: CardinalDirection) -> Window? {
        if let window { return window }
        guard let orientation else { return mostRecentChild?.findLeafWindowRecursive(snappedTo: direction) }
        if direction.orientation == orientation {
            return (direction.isPositive ? children.last : children.first)?
                .findLeafWindowRecursive(snappedTo: direction)
        } else {
            return mostRecentChild?.findLeafWindowRecursive(snappedTo: direction)
        }
    }
}

@MainActor
struct FocusSnapshot {
    private let target: LiveFocus
    private let initialFocusContext: FocusContext
    private let root: FocusTreeNode
    private let windows: [OpaqueWindowId: FocusTreeNode]

    static func capture(target: LiveFocus, includeFloating: Bool) async throws -> FocusSnapshot {
        let initialFocusContext = FocusContext.current
        var builder = FocusTreeBuilder()
        let root = builder.copy(container: target.workspace.rootTilingContainer)
        if includeFloating {
            try await builder.insertFloatingWindows(from: target.workspace, into: root)
        }
        return FocusSnapshot(
            target: target,
            initialFocusContext: initialFocusContext,
            root: root,
            windows: builder.windows,
        )
    }

    func resolveDirectional(_ direction: CardinalDirection) -> Window? {
        guard let focused = target.windowOrNil, let focusedNode = windows[focused.windowId] else { return nil }
        guard let (parent, ownIndex) = focusedNode.closestParent(hasChildrenInDirection: direction) else { return nil }
        return parent.children[ownIndex + direction.focusOffset]
            .findLeafWindowRecursive(snappedTo: direction.opposite)
    }

    func resolveWorkspaceWrap(direction: CardinalDirection) -> Window? {
        root.findLeafWindowRecursive(snappedTo: direction.opposite)
    }

    func dfsWindows() -> [Window] {
        root.allLeafWindowsRecursive()
    }

    func focusIfStillCurrent(_ window: Window) -> BinaryExitCode {
        guard initialFocusContext.matchesCurrent() else { return .succ }
        guard Window.get(byId: window.windowId) === window else { return .succ }
        guard window.toLiveFocusOrNil() != nil else { return .succ }
        return .from(bool: window.focusWindow())
    }
}

@MainActor
private struct FocusTreeBuilder {
    var windows: [OpaqueWindowId: FocusTreeNode] = [:]
    private var nodes: [ObjectIdentifier: FocusTreeNode] = [:]

    mutating func copy(container: TilingContainer) -> FocusTreeNode {
        let node = FocusTreeNode(container: container)
        nodes[ObjectIdentifier(container)] = node

        for child in container.inhabitedChildren {
            let copied = switch child.tilingTreeNodeCasesOrDie() {
                case .window(let window): copy(window: window, role: .tiling)
                case .tilingContainer(let container): copy(container: container)
            }
            node.append(copied)
        }

        if let mostRecentChild = container.mostRecentInhabitedChild {
            node.setMostRecentChild(nodes[ObjectIdentifier(mostRecentChild)])
        }
        return node
    }

    private mutating func copy(window: Window, role: FocusCandidateRole) -> FocusTreeNode {
        let node = FocusTreeNode(window: window, role: role)
        nodes[ObjectIdentifier(window)] = node
        windows[window.windowId] = node
        return node
    }

    mutating func insertFloatingWindows(from workspace: Workspace, into root: FocusTreeNode) async throws {
        var pending: [PendingFloatingFocusNode] = []
        for window in workspace.floatingWindows {
            guard let center = try await window.getCenter(.nonCancellable) else { continue }
            let virtualParent: FocusTreeNode
            let parentOrientation: Orientation
            let index: Int
            if let target = center.coerce(in: workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps)?
                .findWindowRecursively(in: workspace.rootTilingContainer, virtual: true, fullscreenCoversAll: false),
                let targetCenter = try await target.getCenter(.nonCancellable),
                let tilingParent = target.parent as? TilingContainer,
                let mappedParent = nodes[ObjectIdentifier(tilingParent)]
            {
                virtualParent = mappedParent
                parentOrientation = tilingParent.orientation
                index = center.getProjection(parentOrientation) >= targetCenter.getProjection(parentOrientation)
                    ? target.ownIndex(in: .all).orDie() + 1
                    : target.ownIndex(in: .all).orDie()
            } else {
                virtualParent = root
                parentOrientation = root.orientation.orDie()
                index = 0
            }
            pending.append(PendingFloatingFocusNode(
                window: window,
                center: center,
                parent: virtualParent,
                parentOrientation: parentOrientation,
                index: index,
            ))
        }

        for floating in pending.sortedBy({ $0.center.getProjection($0.parentOrientation) }).reversed() {
            let node = copy(window: floating.window, role: .floating)
            floating.parent.insert(node, at: floating.index)
        }
    }
}

@MainActor
private struct PendingFloatingFocusNode {
    let window: Window
    let center: Point
    let parent: FocusTreeNode
    let parentOrientation: Orientation
    let index: Int
}
