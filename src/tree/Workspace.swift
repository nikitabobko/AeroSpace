private var workspaceNameToWorkspace: [String: Workspace] = [:]

private var screenPointToVisibleWorkspace: [CGPoint: Workspace] = [:]
private var visibleWorkspaceToScreenPoint: [Workspace: CGPoint] = [:]

private var emptyInvisibleWorkspaceGenerator: some IteratorProtocol<Workspace> {
    (0...Int.max).lazy
        .map { Workspace.get(byName: "EMPTY\($0)") }
        .filter { $0.isEffectivelyEmpty || !$0.isVisible }
        .makeIterator()
}

func getOrCreateNextEmptyInvisibleWorkspace() -> Workspace { // todo rework. it should accept target monitor as a parameter
    var generator = emptyInvisibleWorkspaceGenerator
    return generator.next() ?? errorT("Can't create empty workspace")
}

class Workspace: TreeNode, NonLeafTreeNode, Hashable, Identifiable, CustomStringConvertible {
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

    var description: String {
        let description = [
            ("name", name),
            ("isVisible", String(isVisible)),
            ("isEffectivelyEmpty", String(isEffectivelyEmpty)),
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

    // It can't be converted to property because stupid Swift requires Monitor to be `var`
    // if you want to assign to calculated property
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

    let newScreens = monitors.map(\.rect.topLeftCorner)
    var newScreenToOldScreenMapping: [CGPoint:CGPoint] = [:]
    var preservedOldScreens: [CGPoint] = []
    for newScreen in newScreens {
        if let oldScreen = oldVisibleScreens.minBy({ ($0 - newScreen).vectorLength }) {
            check(oldVisibleScreens.remove(oldScreen) != nil)
            newScreenToOldScreenMapping[newScreen] = oldScreen
            preservedOldScreens.append(oldScreen)
        }
    }

    let oldScreenPointToVisibleWorkspace = screenPointToVisibleWorkspace.filter { preservedOldScreens.contains($0.key) }
    var nextWorkspace = (Workspace.all - Array(oldScreenPointToVisibleWorkspace.values)).makeIterator()
    var nextEmptyWorkspace = emptyInvisibleWorkspaceGenerator
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
