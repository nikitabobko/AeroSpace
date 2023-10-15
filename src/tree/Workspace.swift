// todo make it configurable
// todo make default choice

//private func createDefaultWorkspaceContainer(_ workspace: Workspace) -> TilingContainer {
//    guard let monitorRect = focusedMonitorOrNilIfDesktop?.rect else { return TilingContainer.newHList(parent: workspace) }
//    return monitorRect.width > monitorRect.height ? TilingContainer.newVList(parent: workspace) : TilingContainer.newHList(parent: workspace)
//}

private var workspaceNameToWorkspace: [String: Workspace] = [:]

private var screenPointToVisibleWorkspace: [CGPoint: Workspace] = [:]
private var visibleWorkspaceToScreenPoint: [Workspace: CGPoint] = [:]

func getOrCreateNextEmptyWorkspace() -> Workspace { // todo drop
    let all = Workspace.all
    if let existing = all.first(where: \.isEffectivelyEmpty) {
        return existing
    }
    let occupiedNames = all.map(\.name).toSet()
    let newName = (0...Int.max).lazy.map { "EMPTY\($0)" }.first { !occupiedNames.contains($0) }
            ?? errorT("Can't create empty workspace")
    return Workspace.get(byName: newName)
}

var allMonitorsRectsUnion: Rect {
    monitors.map(\.rect).union()
}

class Workspace: TreeNode, NonLeafTreeNode, Hashable, Identifiable {
    let name: String
    var id: String { name } // satisfy Identifiable
    /// This variable must be interpreted only when the workspace is invisible
    fileprivate var assignedMonitorPoint: CGPoint? = nil

    private init(_ name: String) {
        self.name = name
        super.init(parent: NilTreeNode.instance, adaptiveWeight: 0, index: 0)
    }

    static var all: [Workspace] {
        workspaceNameToWorkspace.values.sortedBy(\.name)
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

    override func getWeight(_ targetOrientation: Orientation) -> CGFloat {
        monitor.visibleRect.getDimension(targetOrientation)
    }

    override func setWeight(_ targetOrientation: Orientation, _ newValue: CGFloat) {
        error("It's not possible to change weight of Workspace")
    }

    static func garbageCollectUnusedWorkspaces() {
        let preservedNames = config.workspaceNames.toSet()
        for name in preservedNames {
            _ = get(byName: name) // Make sure that all preserved workspaces are "cached"
        }
        workspaceNameToWorkspace = workspaceNameToWorkspace.filter { (_, workspace: Workspace) in
            preservedNames.contains(workspace.name) ||
                !workspace.isEffectivelyEmpty ||
                workspace.isVisible ||
                workspace.name == focusedWorkspaceName
        }
    }

    static func ==(lhs: Workspace, rhs: Workspace) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

extension Workspace {
    var isVisible: Bool { visibleWorkspaceToScreenPoint.keys.contains(self) }
    var monitor: Monitor {
        visibleWorkspaceToScreenPoint[self]?.monitorApproximation
            ?? assignedMonitorPoint?.monitorApproximation
            ?? mainMonitor
    }

    var rootTilingContainer: TilingContainer {
        let containers = children.filterIsInstance(of: TilingContainer.self)
        switch containers.count {
        case 0:
            return TilingContainer.newHList(parent: self, adaptiveWeight: 1, index: BIND_LAST_INDEX) // todo createDefaultWorkspaceContainer(self)
        case 1:
            return containers.singleOrNil()!
        default:
            error("Workspace must contain zero or one tiling container as its child")
        }
    }

    static var focused: Workspace { Workspace.get(byName: focusedWorkspaceName) } // todo drop?
}

extension Monitor {
    func getActiveWorkspace() -> Workspace {
        if let existing = screenPointToVisibleWorkspace[rect.topLeftCorner] {
            return existing
        }
        // What if monitor configuration changed? (frame.origin is changed)
        rearrangeWorkspacesOnMonitors()
        // Normally, recursion should happen only once more because we must take the value from the cache
        // (Unless, monitor configuration data race happens)
        return getActiveWorkspace()
    }

    func setActiveWorkspace(_ workspace: Workspace) {
        rect.topLeftCorner.setActiveWorkspace(workspace)
    }
}

private extension CGPoint {
    func setActiveWorkspace(_ workspace: Workspace) {
        if let prevMonitorPoint = visibleWorkspaceToScreenPoint[workspace] {
            visibleWorkspaceToScreenPoint.removeValue(forKey: workspace)
            screenPointToVisibleWorkspace.removeValue(forKey: prevMonitorPoint)
        }
        if let prevWorkspace = screenPointToVisibleWorkspace[self] {
            screenPointToVisibleWorkspace.removeValue(forKey: self)
            visibleWorkspaceToScreenPoint.removeValue(forKey: prevWorkspace)
        }
        visibleWorkspaceToScreenPoint[workspace] = self
        screenPointToVisibleWorkspace[self] = workspace
        workspace.assignedMonitorPoint = self
    }
}

private func rearrangeWorkspacesOnMonitors() {
    var oldVisibleScreens: Set<CGPoint> = screenPointToVisibleWorkspace.keys.toSet()

    let newScreens = NSScreen.screens.map(\.rect.topLeftCorner)
    var newScreenToOldScreenMapping: [CGPoint:CGPoint] = [:]
    var preservedOldScreens: [CGPoint] = []
    for newScreen in newScreens {
        if let oldScreen = oldVisibleScreens.minBy({ ($0 - newScreen).vectorLength }) {
            precondition(oldVisibleScreens.remove(oldScreen) != nil)
            newScreenToOldScreenMapping[newScreen] = oldScreen
            preservedOldScreens.append(oldScreen)
        }
    }

    let oldScreenPointToVisibleWorkspace = screenPointToVisibleWorkspace.filter { preservedOldScreens.contains($0.key) }
    var nextWorkspace = (Workspace.all - Array(oldScreenPointToVisibleWorkspace.values)).makeIterator()
    var nextEmptyWorkspace = (0...Int.max).lazy.map { Workspace.get(byName: "EMPTY\($0)")  }.makeIterator()
    screenPointToVisibleWorkspace = [:]
    visibleWorkspaceToScreenPoint = [:]

    for newScreen in newScreens {
        if let existingVisibleWorkspace = newScreenToOldScreenMapping[newScreen]?.lets({ oldScreenPointToVisibleWorkspace[$0] }) {
            newScreen.setActiveWorkspace(existingVisibleWorkspace)
        } else {
            let workspace = nextWorkspace.next() ?? nextEmptyWorkspace.next() ?? errorT("Can't create next empty workspace")
            newScreen.setActiveWorkspace(workspace)
        }
    }
}
