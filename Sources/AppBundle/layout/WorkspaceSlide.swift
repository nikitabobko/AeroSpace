import AppKit
import Common

enum WorkspaceSlideDirection: Equatable, Sendable {
    case towardsLeft
    case towardsRight
}

struct WorkspaceSlide: Equatable, Sendable {
    let monitorRect: Rect
    let direction: WorkspaceSlideDirection
    let durationMs: Int

    func entryTopLeft(for target: CGPoint) -> CGPoint {
        switch direction {
            case .towardsLeft: CGPoint(x: target.x + monitorRect.width, y: target.y)
            case .towardsRight: CGPoint(x: target.x - monitorRect.width, y: target.y)
        }
    }

    func exitTopLeft(from frame: Rect) -> CGPoint {
        switch direction {
            case .towardsLeft: CGPoint(x: min(frame.topLeftX - monitorRect.width, monitorRect.minX - frame.width), y: frame.topLeftY)
            case .towardsRight: CGPoint(x: max(frame.topLeftX + monitorRect.width, monitorRect.maxX), y: frame.topLeftY)
        }
    }
}

func workspaceSlideDirection(from previous: Workspace, to next: Workspace) -> WorkspaceSlideDirection {
    previous < next ? .towardsLeft : .towardsRight
}

func isWorkspaceSlideSafe(monitorRect: Rect, otherMonitorRects: [Rect]) -> Bool {
    let leftStrip = monitorRect.with(\.topLeftX, monitorRect.topLeftX - monitorRect.width)
    let rightStrip = monitorRect.with(\.topLeftX, monitorRect.topLeftX + monitorRect.width)
    return !otherMonitorRects.contains { $0.intersects(leftStrip) || $0.intersects(rightStrip) }
}

struct WorkspaceSlides {
    var incoming: [Workspace: WorkspaceSlide] = [:]
    var outgoing: [Workspace: WorkspaceSlide] = [:]
}

func detectWorkspaceSlides(
    previous: [CGPoint: String],
    current: [CGPoint: Workspace],
    monitorRects: [CGPoint: Rect],
    existingWorkspaces: [String: Workspace],
    durationMs: Int,
) -> WorkspaceSlides {
    var result = WorkspaceSlides()
    if durationMs <= 0 { return result }
    let previouslyVisible = Set(previous.values)
    let currentlyVisible = Set(current.values.map(\.name))
    for (monitorKey, next) in current {
        guard let previousName = previous[monitorKey],
              previousName != next.name,
              !previouslyVisible.contains(next.name),
              !currentlyVisible.contains(previousName),
              let previousWorkspace = existingWorkspaces[previousName],
              let monitorRect = monitorRects[monitorKey]
        else { continue }
        let otherMonitorRects = monitorRects.filter { $0.key != monitorKey }.map(\.value)
        guard isWorkspaceSlideSafe(monitorRect: monitorRect, otherMonitorRects: otherMonitorRects) else { continue }
        let slide = WorkspaceSlide(
            monitorRect: monitorRect,
            direction: workspaceSlideDirection(from: previousWorkspace, to: next),
            durationMs: durationMs,
        )
        result.incoming[next] = slide
        result.outgoing[previousWorkspace] = slide
    }
    return result
}

extension Rect {
    fileprivate func intersects(_ other: Rect) -> Bool {
        minX < other.maxX && other.minX < maxX && minY < other.maxY && other.minY < maxY
    }
}
