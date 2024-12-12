import AppKit
import Common

private var workspaceNameToWorkspace: [String: Workspace] = [:]

private var screenPointToPrevVisibleWorkspace: [CGPoint: String] = [:]
private var screenPointToVisibleWorkspace: [CGPoint: Workspace] = [:]
private var visibleWorkspaceToScreenPoint: [Workspace: CGPoint] = [:]

// The returned workspace must be invisible and it must belong to the requested monitor
func getStubWorkspace(for monitor: Monitor) -> Workspace {
    getStubWorkspace(forPoint: monitor.rect.topLeftCorner)
}

private func getStubWorkspace(forPoint point: CGPoint) -> Workspace {
    if let prev = screenPointToPrevVisibleWorkspace[point]?.lets({ Workspace.get(byName: $0) }),
       !prev.isVisible && prev.workspaceMonitor.rect.topLeftCorner == point && prev.forceAssignedMonitor == nil
    {
        return prev
    }
    if let candidate = Workspace.all
        .first(where: { !$0.isVisible && $0.workspaceMonitor.rect.topLeftCorner == point })
    {
        return candidate
    }
    let preservedNames = config.preservedWorkspaceNames.toSet()
    return (1 ... Int.max).lazy
        .map { Workspace.get(byName: String($0)) }
        .first { $0.isEffectivelyEmpty && !$0.isVisible && !preservedNames.contains($0.name) && $0.forceAssignedMonitor == nil }
        ?? errorT("Can't create empty workspace")
}

class Workspace: TreeNode, NonLeafTreeNodeObject, Hashable, CustomStringConvertible, Comparable {
    let name: String
    private let nameLogicalSegments: StringLogicalSegments
    /// `assignedMonitorPoint` must be interpreted only when the workspace is invisible
    fileprivate var assignedMonitorPoint: CGPoint? = nil

    private init(_ name: String) {
        self.name = name
        self.nameLogicalSegments = name.toLogicalSegments()
        super.init(parent: NilTreeNode.instance, adaptiveWeight: 0, index: 0)
    }

    static var all: [Workspace] {
        workspaceNameToWorkspace.values.sorted()
    }

    static func get(byName name: String) -> Workspace {
        if let existing = workspaceNameToWorkspace[name] {
            return existing
        } else {
            let workspace = Workspace(name)
            workspaceNameToWorkspace[name] = workspace
            return workspace
        }
    }

    static func < (lhs: Workspace, rhs: Workspace) -> Bool { lhs.nameLogicalSegments < rhs.nameLogicalSegments }

    override func getWeight(_ targetOrientation: Orientation) -> CGFloat {
        workspaceMonitor.visibleRectPaddedByOuterGaps.getDimension(targetOrientation)
    }

    override func setWeight(_ targetOrientation: Orientation, _ newValue: CGFloat) {
        error("It's not possible to change weight of Workspace")
    }

    var description: String {
        let preservedNames = config.preservedWorkspaceNames.toSet()
        let description = [
            ("name", name),
            ("isVisible", String(isVisible)),
            ("isEffectivelyEmpty", String(isEffectivelyEmpty)),
            ("doKeepAlive", String(preservedNames.contains(name))),
        ].map { "\($0.0): '\(String(describing: $0.1))'" }.joined(separator: ", ")
        return "Workspace(\(description))"
    }

    static func garbageCollectUnusedWorkspaces() {
        let preservedNames = config.preservedWorkspaceNames.toSet()
        for name in preservedNames {
            _ = get(byName: name) // Make sure that all preserved workspaces are "cached"
        }
        workspaceNameToWorkspace = workspaceNameToWorkspace.filter { (_, workspace: Workspace) in
            preservedNames.contains(workspace.name) ||
                !workspace.isEffectivelyEmpty ||
                workspace.isVisible ||
                workspace.name == focus.workspace.name
        }
    }

    static func == (lhs: Workspace, rhs: Workspace) -> Bool {
        check((lhs === rhs) == (lhs.name == rhs.name), "lhs: \(lhs) rhs: \(rhs)")
        return lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

extension Workspace {
    var isVisible: Bool { visibleWorkspaceToScreenPoint.keys.contains(self) }
    var workspaceMonitor: Monitor {
        forceAssignedMonitor
            ?? visibleWorkspaceToScreenPoint[self]?.monitorApproximation
            ?? assignedMonitorPoint?.monitorApproximation
            ?? defaultAssignedMonitor
            ?? mainMonitor
    }
}

extension Monitor {
    var activeWorkspace: Workspace {
        if let existing = screenPointToVisibleWorkspace[rect.topLeftCorner] {
            return existing
        }
        // What if monitor configuration changed? (frame.origin is changed)
        rearrangeWorkspacesOnMonitors()
        // Normally, recursion should happen only once more because we must take the value from the cache
        // (Unless, monitor configuration data race happens)
        return self.activeWorkspace
    }

    func setActiveWorkspace(_ workspace: Workspace) -> Bool {
        rect.topLeftCorner.setActiveWorkspace(workspace)
    }
}

func gcMonitors() {
    if screenPointToVisibleWorkspace.count != monitors.count {
        rearrangeWorkspacesOnMonitors()
    }
}

private extension CGPoint {
    func setActiveWorkspace(_ workspace: Workspace) -> Bool {
        if !isValidAssignment(workspace: workspace, screen: self) {
            return false
        }
        if let prevMonitorPoint = visibleWorkspaceToScreenPoint[workspace] {
            visibleWorkspaceToScreenPoint.removeValue(forKey: workspace)
            screenPointToPrevVisibleWorkspace[prevMonitorPoint] =
                screenPointToVisibleWorkspace.removeValue(forKey: prevMonitorPoint)?.name
        }
        if let prevWorkspace = screenPointToVisibleWorkspace[self] {
            screenPointToPrevVisibleWorkspace[self] =
                screenPointToVisibleWorkspace.removeValue(forKey: self)?.name
            visibleWorkspaceToScreenPoint.removeValue(forKey: prevWorkspace)
        }
        visibleWorkspaceToScreenPoint[workspace] = self
        screenPointToVisibleWorkspace[self] = workspace
        workspace.assignedMonitorPoint = self
        return true
    }
}

private func rearrangeWorkspacesOnMonitors() {
    var oldVisibleScreens: Set<CGPoint> = screenPointToVisibleWorkspace.keys.toSet()

    let newScreens = monitors.map(\.rect.topLeftCorner)
    var newScreenToOldScreenMapping: [CGPoint: CGPoint] = [:]
    for newScreen in newScreens {
        if let oldScreen = oldVisibleScreens.minBy({ ($0 - newScreen).vectorLength }) {
            check(oldVisibleScreens.remove(oldScreen) != nil)
            newScreenToOldScreenMapping[newScreen] = oldScreen
        }
    }

    let oldScreenPointToVisibleWorkspace = screenPointToVisibleWorkspace
    screenPointToVisibleWorkspace = [:]
    visibleWorkspaceToScreenPoint = [:]

    for newScreen in newScreens {
        if let existingVisibleWorkspace = newScreenToOldScreenMapping[newScreen]?.lets({ oldScreenPointToVisibleWorkspace[$0] }),
           newScreen.setActiveWorkspace(existingVisibleWorkspace)
        {
            continue
        }
        let stubWorkspace = getStubWorkspace(forPoint: newScreen)
        check(newScreen.setActiveWorkspace(stubWorkspace),
              "getStubWorkspace generated incompatible stub workspace (\(stubWorkspace)) for the monitor (\(newScreen)")
    }
}

private func isValidAssignment(workspace: Workspace, screen: CGPoint) -> Bool {
    if let forceAssigned = workspace.forceAssignedMonitor, forceAssigned.rect.topLeftCorner != screen {
        return false
    } else {
        return true
    }
}
