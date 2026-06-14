import AppKit
import Common

@MainActor
private struct CmdRightResizeSession {
    let windowId: UInt32
    let startPoint: CGPoint
    let startRect: Rect
    let isFloating: Bool
    let edges: EdgeSet
    let engageX: Bool
    let engageY: Bool
}

@MainActor
private struct EdgeSet {
    let left: Bool
    let right: Bool
    let up: Bool
    let down: Bool
}

@MainActor
private var cmdRightResizeSession: CmdRightResizeSession? = nil

@MainActor
func onCmdRightMouseDown() async {
    guard cmdRightResizeSession == nil else { return }
    let point = mouseLocation
    let targetWorkspace = point.monitorApproximation.activeWorkspace
    guard let window = await findWindowForRightClickResize(at: point, in: targetWorkspace) else { return }
    guard let axRect = try? await window.getAxRect() else { return }
    let rect = window.lastAppliedLayoutPhysicalRect ?? axRect

    let tolerance: CGFloat = 10
    let nearLeft = abs(point.x - rect.minX) <= tolerance
    let nearRight = abs(point.x - rect.maxX) <= tolerance
    let nearUp = abs(point.y - rect.minY) <= tolerance
    let nearDown = abs(point.y - rect.maxY) <= tolerance

    let horizClosestIsLeft = abs(point.x - rect.minX) <= abs(point.x - rect.maxX)
    let vertClosestIsUp = abs(point.y - rect.minY) <= abs(point.y - rect.maxY)
    let edges = EdgeSet(left: horizClosestIsLeft, right: !horizClosestIsLeft, up: vertClosestIsUp, down: !vertClosestIsUp)

    let engageXInitial = nearLeft || nearRight
    let engageYInitial = nearUp || nearDown


    currentlyManipulatedWithMouseWindowId = window.windowId
    cmdRightResizeSession = CmdRightResizeSession(
        windowId: window.windowId,
        startPoint: point,
        startRect: axRect,
        isFloating: window.isFloating,
        edges: edges,
        engageX: engageXInitial,
        engageY: engageYInitial,
    )
}

@MainActor
func onCmdRightMouseDragged() async {
    guard let session = cmdRightResizeSession else { return }
    guard let window = Window.get(byId: session.windowId) else { return }
    let lastAppliedLayoutRect = window.lastAppliedLayoutPhysicalRect

    let point = mouseLocation
    let dx = point.x - session.startPoint.x
    let dy = point.y - session.startPoint.y

    var newTopLeft = session.startRect.topLeftCorner
    var newSize = session.startRect.size

    var engageX = session.engageX
    var engageY = session.engageY
    let expandThreshold: CGFloat = 8
    if !engageX && abs(dx) > expandThreshold { engageX = true }
    if !engageY && abs(dy) > expandThreshold { engageY = true }


    if engageX {
        if session.edges.left {
            newTopLeft.x += dx
            newSize.width -= dx
        }
        if session.edges.right {
            newSize.width += dx
        }
    }

    if engageY {
        if session.edges.up {
            newTopLeft.y += dy
            newSize.height -= dy
        }
        if session.edges.down {
            newSize.height += dy
        }
    }

    if newSize.width < 100 || newSize.height < 100 { return }

    let currentRect = Rect(
        topLeftX: engageX ? newTopLeft.x : session.startRect.topLeftX,
        topLeftY: engageY ? newTopLeft.y : session.startRect.topLeftY,
        width: engageX ? newSize.width : session.startRect.width,
        height: engageY ? newSize.height : session.startRect.height,
    )

    if session.isFloating {
        window.lastFloatingSize = currentRect.size
        window.setAxFrame(currentRect.topLeftCorner, currentRect.size)
    } else if let lastAppliedLayoutRect {
        adjustWeightsForResize(window: window, currentRect: currentRect, lastAppliedLayoutRect: lastAppliedLayoutRect)
        scheduleCancellableCompleteRefreshSession(.globalObserver("cmdRightMouseDragged"), optimisticallyPreLayoutWorkspaces: true)
    }
}

@MainActor
func onCmdRightMouseUp() async {
    cmdRightResizeSession = nil
    try? await resetManipulatedWithMouseIfPossible()
}

@MainActor
private func findWindowForRightClickResize(at point: CGPoint, in workspace: Workspace) async -> Window? {
    for window in workspace.floatingWindows.reversed() {
        if let rect = try? await window.getAxRect(), rect.contains(point) {
            return window
        }
    }
    if let tilingWindow = point.findIn(tree: workspace.rootTilingContainer, virtual: false) {
        return tilingWindow
    }
    return nil
}
