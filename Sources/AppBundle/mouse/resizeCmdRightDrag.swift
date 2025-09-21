import AppKit
import Common


private enum ResizeEdge { case left, right, up, down }

@MainActor
private struct CmdRightResizeSession {
    let windowId: UInt32
    let startPoint: CGPoint
    let edge: ResizeEdge
}

@MainActor
private var cmdRightResizeSession: CmdRightResizeSession? = nil
@MainActor
private var pendingDragRefreshTask: Task<(), Never>? = nil

private func edgeToDirection(_ e: ResizeEdge) -> CardinalDirection {
    switch e {
        case .left: .left
        case .right: .right
        case .up: .up
        case .down: .down
    }
}
private func oppositeEdge(_ e: ResizeEdge) -> ResizeEdge {
    switch e {
        case .left: .right
        case .right: .left
        case .up: .down
        case .down: .up
    }
}

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

    let distances: [(ResizeEdge, CGFloat)] = [
        (.left, abs(point.x - rect.minX)),
        (.right, abs(point.x - rect.maxX)),
        (.up, abs(point.y - rect.minY)),
        (.down, abs(point.y - rect.maxY)),
    ]
    var edge = distances.min(by: { $0.1 < $1.1 })!.0

    func hasNeighbor(_ e: ResizeEdge) -> Bool { resolveParentAndNeighbor(window, edgeToDirection(e)) != nil }
    if !hasNeighbor(edge), hasNeighbor(oppositeEdge(edge)) { edge = oppositeEdge(edge) }
    if !hasNeighbor(edge) { return }

    currentlyManipulatedWithMouseWindowId = window.windowId
    cmdRightResizeSession = CmdRightResizeSession(windowId: window.windowId, startPoint: point, edge: edge)
}

@MainActor
func onCmdRightMouseDragged() async {
    guard let session = cmdRightResizeSession else { return }
    guard let window = Window.get(byId: session.windowId) else { return }

    let point = mouseLocation
    let direction = edgeToDirection(session.edge)
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
    scheduleThrottledRefresh()
}

@MainActor
func onCmdRightMouseUp() async {
    cmdRightResizeSession = nil
    pendingDragRefreshTask?.cancel()
    pendingDragRefreshTask = nil
    try? await resetManipulatedWithMouseIfPossible()
}

@MainActor
private func scheduleThrottledRefresh() {
    if pendingDragRefreshTask != nil { return }
    pendingDragRefreshTask = Task { @MainActor in
        try? await Task.sleep(for: preferredFrameDuration())
        runRefreshSession(.globalObserver("cmdRightMouseDragged"), optimisticallyPreLayoutWorkspaces: true)
        pendingDragRefreshTask = nil
    }
}

@MainActor
private func preferredFrameDuration() -> Duration {
    let maxFps = NSScreen.screens.map { $0.maximumFramesPerSecond }.max() ?? 60
    let fps = max(maxFps, 1)
    let nanosPerFrame = 1_000_000_000 / fps
    return .nanoseconds(nanosPerFrame)
}
