// todo make it configurable
// todo make default choice

//private func createDefaultWorkspaceContainer(_ workspace: Workspace) -> TilingContainer {
//    guard let monitorRect = NSScreen.focusedMonitorOrNilIfDesktop?.rect else { return TilingContainer.newHList(parent: workspace) }
//    return monitorRect.width > monitorRect.height ? TilingContainer.newVList(parent: workspace) : TilingContainer.newHList(parent: workspace)
//}

private var workspaceNameToWorkspace: [String: Workspace] = [:]

/// Empty workspace is spread over all monitors. That's why it's tracked separately. See ``monitorToNotEmptyWorkspace``,
var currentEmptyWorkspace: Workspace = getOrCreateNextEmptyWorkspace()
/// macOS doesn't provide an API to check for currently active/selected monitor
/// (see ``NSScreen.focusedMonitorOrNilIfDesktop``) => when users changes the active monitor by clicking the
/// desktop on different monitor AeroSpace can't detect it => AeroSpace assumes that the empty workspace occupies
/// both monitors.
///
/// If, at the same time, another monitor already contains another not empty workspace `B` then we assume that this
/// monitor contains two workspaces: the empty one and `B` which displayed on top of empty one
///
/// That's why the mental model is the following: the empty workspace is spread over all monitors. And each monitor
/// optionally can have a not empty workspace assigned to it
///
/// When this map contains `Maybe.Nothing` value it means that the monitor displays the "empty"/"background" workspace
private var monitorToNotEmptyWorkspace: [Monitor: Maybe<Workspace>] = [:]

func getOrCreateNextEmptyWorkspace() -> Workspace {
    let all = Workspace.all
    if let existing = all.first(where: { $0.isEffectivelyEmpty }) {
        return existing
    }
    let occupiedNames = all.map { $0.name }.toSet()
    let newName = (0...Int.max).lazy.map { "EMPTY\($0)" }.first { !occupiedNames.contains($0) }
            ?? errorT("Can't create empty workspace")
    return Workspace.get(byName: newName)
}

var allMonitorsRectsUnion: Rect {
    NSScreen.screens.map { $0.rect }.union()
}

class Workspace: TreeNode, NonLeafTreeNode, Hashable, Identifiable {
    let name: String
    var id: String { name } // satisfy Identifiable
    var assignedMonitor: Monitor? = nil

    private init(_ name: String) {
        self.name = name
        super.init(parent: NilTreeNode.instance, adaptiveWeight: 0, index: 0)
    }

    static var all: [Workspace] {
        garbageCollectUnusedWorkspaces()
        return workspaceNameToWorkspace.values.sortedBy { $0.name }
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
        assignedMonitor?.visibleRect.getDimension(targetOrientation)
            ?? errorT("Why do you need to know weight of empty workspace?")
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
                    workspace == currentEmptyWorkspace ||
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
    var isVisible: Bool {
        self == currentEmptyWorkspace || assignedMonitor?.getActiveWorkspace() == self
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

    var assignedMonitorOfNotEmptyWorkspace: Monitor {
        assignedMonitor ?? errorT("Not empty workspace \(workspace.name) must have an assigned monitor")
    }

    static var focused: Workspace { Workspace.get(byName: focusedWorkspaceName) }
}

extension Monitor {
    func getActiveWorkspace() -> Workspace {
        if let existing = monitorToNotEmptyWorkspace[self] {
            return existing.valueOrNil ?? currentEmptyWorkspace
        }
        // What if monitor configuration changed? (frame.origin is changed)
        rearrangeWorkspacesOnMonitors()
        // Normally, recursion should happen only once more because we must take the value from the cache
        // (Unless, monitor configuration data race happens)
        return self.getActiveWorkspace()
    }

    func setActiveWorkspace(_ workspace: Workspace) {
        if workspace.isEffectivelyEmpty {
            monitorToNotEmptyWorkspace[self] = Maybe.Nothing
            currentEmptyWorkspace = workspace
        } else {
            monitorToNotEmptyWorkspace[self] = Maybe.Just(workspace)
            workspace.assignedMonitor = self
        }
    }
}

// todo rewrite. Create old monitor -> new monitor mapping Need to update assignedMonitors.
private func rearrangeWorkspacesOnMonitors() {
    let oldMonitorToWorkspaces: [Monitor: Maybe<Workspace>] = monitorToNotEmptyWorkspace
    monitorToNotEmptyWorkspace = [:]
    let monitors = NSScreen.screens.map { $0.monitor }.toSet()
    let preservedWorkspaces: [Workspace] = oldMonitorToWorkspaces
        .filter { oldMonitor, oldWorkspace in monitors.contains(oldMonitor) }
        .map { $0.value.valueOrNil }
        .filterNotNil()
    let lostWorkspaces: [Workspace] = oldMonitorToWorkspaces
        .filter { oldMonitor, oldWorkspace in !monitors.contains(oldMonitor) }
        .map { $0.value.valueOrNil }
        .filterNotNil()
    var poolOfWorkspaces: [Workspace] =
        Workspace.all.reversed() - (preservedWorkspaces + lostWorkspaces) + lostWorkspaces
    for monitor in monitors {
        // If monitors change, most likely we will preserve only the main monitor (It always has (0, 0) origin)
        if let existing = oldMonitorToWorkspaces[monitor] {
            monitorToNotEmptyWorkspace[monitor] = existing
        } else {
            monitorToNotEmptyWorkspace[monitor] = Maybe.from(poolOfWorkspaces.popLast())
        }
    }
}
