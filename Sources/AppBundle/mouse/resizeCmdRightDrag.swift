import AppKit
import Common

@MainActor
private struct CmdRightResizeSession {
    let windowId: UInt32
    let startPoint: CGPoint
    let startRect: Rect
    let edge: CardinalDirection
}

@MainActor
private var cmdRightResizeSession: CmdRightResizeSession? = nil

@MainActor
func onCmdRightMouseDown() async {
    guard cmdRightResizeSession == nil else { return }
    let point = mouseLocation
    let targetWorkspace = point.monitorApproximation.activeWorkspace
    guard let window = point.findIn(tree: targetWorkspace.rootTilingContainer, virtual: false) else { return }
    guard let rect = window.lastAppliedLayoutPhysicalRect else { return }
    guard let axRect = try? await window.getAxRect() else { return }

    let distances: [(CardinalDirection, CGFloat)] = [
        (.left, abs(point.x - rect.minX)),
        (.right, abs(point.x - rect.maxX)),
        (.up, abs(point.y - rect.minY)),
        (.down, abs(point.y - rect.maxY)),
    ]
    let edge = distances.min(by: { $0.1 < $1.1 })!.0

    currentlyManipulatedWithMouseWindowId = window.windowId
    cmdRightResizeSession = CmdRightResizeSession(windowId: window.windowId, startPoint: point, startRect: axRect, edge: edge)
}

@MainActor
func onCmdRightMouseDragged() async {
    guard let session = cmdRightResizeSession else { return }
    guard let window = Window.get(byId: session.windowId) else { return }
    guard let lastAppliedLayoutRect = window.lastAppliedLayoutPhysicalRect else { return }

    let point = mouseLocation
    let edge = session.edge
    let delta: CGFloat = (edge.orientation == .h) ? (point.x - session.startPoint.x) : (point.y - session.startPoint.y)

    var newTopLeft = session.startRect.topLeftCorner
    var newSize = session.startRect.size

    switch edge {
        case .left:
            newTopLeft.x += delta
            newSize.width -= delta
        case .right:
            newSize.width += delta
        case .up:
            newTopLeft.y += delta
            newSize.height -= delta
        case .down:
            newSize.height += delta
    }

    if newSize.width < 100 || newSize.height < 100 { return }

    let newRect = Rect(topLeftX: newTopLeft.x, topLeftY: newTopLeft.y, width: newSize.width, height: newSize.height)
    adjustWeightsForResize(window: window, currentRect: newRect, lastAppliedLayoutRect: lastAppliedLayoutRect)
    runRefreshSession(.globalObserver("cmdRightMouseDragged"), optimisticallyPreLayoutWorkspaces: true)
}

@MainActor
func onCmdRightMouseUp() async {
    cmdRightResizeSession = nil
    try? await resetManipulatedWithMouseIfPossible()
}
