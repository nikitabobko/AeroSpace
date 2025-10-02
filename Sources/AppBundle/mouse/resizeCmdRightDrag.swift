import AppKit
import Common

@MainActor
private struct CmdRightResizeSession {
    let windowId: UInt32
    let startPoint: CGPoint
    let edge: CardinalDirection
}

@MainActor
private var cmdRightResizeSession: CmdRightResizeSession? = nil
@MainActor
private var cmdRightDragRefreshTask: Task<(), any Error>? = nil



@MainActor
private func resolveParentAndNeighbor(_ window: Window, _ direction: CardinalDirection) -> (parent: TilingContainer, ownIndex: Int, neighborIndex: Int, orientation: Orientation)? {
    guard let (parent, ownIndex) = window.closestParent(hasChildrenInDirection: direction, withLayout: .tiles) else { return nil }
    let neighborIndex = ownIndex + direction.focusOffset
    guard parent.children.indices.contains(neighborIndex) else { return nil }
    return (parent, ownIndex, neighborIndex, parent.orientation)
}

@MainActor
func onCmdRightMouseDown() async {
    guard cmdRightResizeSession == nil else { return }
    let point = mouseLocation
    let targetWorkspace = point.monitorApproximation.activeWorkspace
    guard let window = point.findIn(tree: targetWorkspace.rootTilingContainer, virtual: false) else { return }
    guard let rect = window.lastAppliedLayoutPhysicalRect else { return }

    let distances: [(CardinalDirection, CGFloat)] = [
        (.left, abs(point.x - rect.minX)),
        (.right, abs(point.x - rect.maxX)),
        (.up, abs(point.y - rect.minY)),
        (.down, abs(point.y - rect.maxY)),
    ]
    var edge = distances.min(by: { $0.1 < $1.1 })!.0

    func hasNeighbor(_ e: CardinalDirection) -> Bool { resolveParentAndNeighbor(window, e) != nil }
    if !hasNeighbor(edge), hasNeighbor(edge.opposite) { edge = edge.opposite }
    if !hasNeighbor(edge) { return }

    currentlyManipulatedWithMouseWindowId = window.windowId
    cmdRightResizeSession = CmdRightResizeSession(windowId: window.windowId, startPoint: point, edge: edge)
}

@MainActor
func onCmdRightMouseDragged() async {
    guard let session = cmdRightResizeSession else { return }
    guard let window = Window.get(byId: session.windowId) else { return }

    let point = mouseLocation
    let direction = session.edge
    let delta: CGFloat = (direction.orientation == .h) ? (point.x - session.startPoint.x) : (point.y - session.startPoint.y)
    let diff: CGFloat = direction.isPositive ? delta : -delta

    guard let (parent, _, neighborIndex, orientation) = resolveParentAndNeighbor(window, direction) else { return }
    if abs(diff) < 1 { return }

    window.parentsWithSelf.lazy
        .prefix(while: { $0 !== parent })
        .compactMap { node -> TreeNode? in
            let p = node.parent as? TilingContainer
            return (p?.orientation == orientation && p?.layout == .tiles) ? node : nil
        }
        .forEach { $0.setWeight(orientation, $0.getWeightBeforeResize(orientation) + diff) }

    let sibling = parent.children[neighborIndex]
    sibling.setWeight(orientation, sibling.getWeightBeforeResize(orientation) - diff)

    currentlyManipulatedWithMouseWindowId = window.windowId
    cmdRightDragRefreshTask?.cancel()
    cmdRightDragRefreshTask = Task {
        try checkCancellation()
        runRefreshSession(.globalObserver("cmdRightMouseDragged"), optimisticallyPreLayoutWorkspaces: true)
    }
}

@MainActor
func onCmdRightMouseUp() async {
    cmdRightResizeSession = nil
    cmdRightDragRefreshTask?.cancel()
    cmdRightDragRefreshTask = nil
    try? await resetManipulatedWithMouseIfPossible()
}
