import AppKit
import Common

@MainActor private var pointToMonitor: [CGPoint: Monitor] = [:]

final class Monitor: TreeNode, NonLeafTreeNodeObject {
    fileprivate var _info: MonitorInfo
    var info: MonitorInfo { _info }

    @MainActor fileprivate init(_ info: MonitorInfo) {
        self._info = info
        super.init(parent: NilTreeNode.instance, adaptiveWeight: 0, index: 0)
    }

    override func getWeight(_ targetOrientation: Orientation) -> CGFloat {
        info.visibleRectPaddedByOuterGaps.getDimension(targetOrientation)
    }

    override func setWeight(_ targetOrientation: Orientation, _ newValue: CGFloat) {
        die("It's not possible to change weight of Monitor")
    }

    @MainActor static var all: [Monitor] { Array(pointToMonitor.values) }
}

@MainActor private func rearrangeMonitors() {
    var newMonitorPoints = globalUnsortedMonitorInfos.grouped(by: { $0.rect.topLeftCorner }).mapValues { $0.singleOrNil().orDie() }

    var oldPointToMonitor = pointToMonitor
    pointToMonitor = [:]

    var newPointToClosestOldPoint = [CGPoint: CGPoint]()
    var oldPointToClosestNewPoint = [CGPoint: CGPoint]()

    for point in newMonitorPoints.keys {
        newPointToClosestOldPoint[point] = oldPointToMonitor.keys.minBy { ($0 - point).vectorLength }
    }

    for point in oldPointToMonitor.keys {
        oldPointToClosestNewPoint[point] = newMonitorPoints.keys.minBy { ($0 - point).vectorLength }
    }

    for (newPoint, closestOldPoint) in newPointToClosestOldPoint {
        if oldPointToClosestNewPoint[closestOldPoint] == newPoint { // Closest points of each other
            pointToMonitor[newPoint] = oldPointToMonitor.removeValue(forKey: closestOldPoint)
            pointToMonitor[newPoint].orDie()._info = newMonitorPoints.removeValue(forKey: newPoint).orDie()
        }
    }

    var monitors = oldPointToMonitor.values.sortedBy { $0.info.rect.topLeftCorner.vectorLength } // [Monitor]
    let monitorInfos = newMonitorPoints.values.sortedBy { $0.rect.topLeftCorner.vectorLength } // [MonitorInfo]

    let mainMonitor = pointToMonitor[CGPoint(x: 0, y: 0)] ?? pointToMonitor.first?.value
    while monitors.count > monitorInfos.count, let mainMonitor {
        let monitor = monitors.removeLast()
        for child in monitor.children {
            switch child.nodeCases {
                case .floatingWindowsContainer,
                     .macosFullscreenWindowsContainer,
                     .macosHiddenAppsWindowsContainer,
                     .macosMinimizedWindowsContainer,
                     .macosPopupWindowsContainer,
                     .monitor,
                     .tilingContainer,
                     .window,
                     .workspace: illegalChildParentRelation(child: child, parent: monitor)
                case .workspacesContainer(let it):
                    for workspace in it.children {
                        workspace.bind(to: mainMonitor.getWorkspacesContainerOrCreate(), adaptiveWeight: 1, index: INDEX_BIND_LAST)
                    }
            }
        }
    }

    for j in monitors.indices {
        monitors[j]._info = monitorInfos.getOrNil(atIndex: j).orDie()
        pointToMonitor[monitors[j].info.rect.topLeftCorner] = monitors[j]
    }

    var i = monitors.count
    while let monitorInfo = monitorInfos.getOrNil(atIndex: i) {
        let monitor = Monitor(monitorInfo)
        monitors.append(monitor)
        pointToMonitor[monitor.info.rect.topLeftCorner] = monitor
        i += 1
    }
}

extension MonitorInfo {
    @MainActor var visibleWorkspace: Workspace { // todo revisit this API
        let monitor = toMonitorOrRearrangeMonitors()
        return monitor.getWorkspacesContainerOrCreate().getVisibleWorkspaceOrCreate(parent: monitor)
    }

    @MainActor func toMonitorOrRearrangeMonitors() -> Monitor {
        if let existing = pointToMonitor[rect.topLeftCorner] {
            return existing
        }
        rearrangeMonitors() // If monitor configuration changed
        // Normally, recursion should happen only once more because we must take the value from the cache
        // (Unless, monitor configuration data race happens)
        return self.toMonitorOrRearrangeMonitors()
    }

    @MainActor func setVisibleWorkspace(_ workspace: Workspace) -> Bool { // todo revisit this API (new name: setVisibleWorkspace)
        let container = toMonitorOrRearrangeMonitors().getWorkspacesContainerOrCreate()
        return container.setVisibleWorkspace(workspace)
    }

    @MainActor func bindWorkspace(_ workspace: Workspace) -> Bool {
        return toMonitorOrRearrangeMonitors().getWorkspacesContainerOrCreate().bindWorkspace(workspace)
    }
}

@MainActor func gcMonitors() {
    let freshInfos = globalUnsortedMonitorInfos
    // Comparing only the count is not enough: when a monitor is replaced (or its resolution changes) while the number
    // of monitors stays the same, the cached MonitorInfo keeps the geometry of the old display, and all the layouts
    // are computed for a screen that no longer exists (windows end up outside the visible area)
    if pointToMonitor.count != freshInfos.count || freshInfos.contains(where: { !isCachedMonitorInfoUpToDate($0) }) {
        rearrangeMonitors()
    }
}

@MainActor private func isCachedMonitorInfoUpToDate(_ fresh: MonitorInfo) -> Bool {
    guard let cached = pointToMonitor[fresh.rect.topLeftCorner]?.info else { return false }
    return cached.name == fresh.name &&
        cached.rect.topLeftX == fresh.rect.topLeftX &&
        cached.rect.topLeftY == fresh.rect.topLeftY &&
        cached.rect.width == fresh.rect.width &&
        cached.rect.height == fresh.rect.height &&
        cached.visibleRect.topLeftX == fresh.visibleRect.topLeftX &&
        cached.visibleRect.topLeftY == fresh.visibleRect.topLeftY &&
        cached.visibleRect.width == fresh.visibleRect.width &&
        cached.visibleRect.height == fresh.visibleRect.height
}
