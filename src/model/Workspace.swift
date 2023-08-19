import Foundation

// todo make it configurable
// todo make default choice
private func createDefaultWorkspaceContainer(_ workspace: Workspace) -> TilingContainer {
    guard let monitorRect = NSScreen.focusedMonitorOrNilIfDesktop?.rect else { return HListContainer(parent: workspace) }
    return monitorRect.width > monitorRect.height ? VListContainer(parent: workspace) : HListContainer(parent: workspace)
}
// todo fetch from real settings
let initialWorkspace = settings[0]

private var workspaceNameToWorkspace: [String: Workspace] = [:]

/// Empty workspace is spread over all monitors. That's why it's tracked separately. See ``monitorTopLeftCornerToNotEmptyWorkspace``,
var currentEmptyWorkspace: Workspace = Workspace.get(byName: "???") // todo assign unique default name
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
/// When this map contains `nil` it means that the monitor displays the "empty"/"background" workspace
private var monitorTopLeftCornerToNotEmptyWorkspace: [CGPoint: Workspace?] = [:]

class Workspace: TreeNode, Hashable {
    let name: String
    var floatingWindows = WeakSet<MacWindow>()
    var rootContainer: TilingContainer = HListContainer(parent: RootTreeNode.instance)
    var isVisible: Bool = false
    weak var lastActiveWindow: MacWindow?

    private init(name: String) {
        self.name = name
        super.init(parent: RootTreeNode.instance)
        rootContainer = createDefaultWorkspaceContainer(self)
    }

    func add(window: MacWindow) {
        floatingWindows.raw.insert(Weak(window))
    }

    func remove(window: MacWindow) {
        floatingWindows.raw.remove(Weak(window))
    }

    var isEmpty: Bool {
        floatingWindows.deref().isEmpty && rootContainer.allWindowsRecursive.isEmpty
    }

    // todo Implement properly
    func moveTo(monitor: NSScreen) {
        for window in floatingWindows.deref() {
            window.setPosition(monitor.visibleRect.topLeft)
        }
    }

    static var all: [Workspace] {
        let preservedNames = settings.map { $0.id }.toSet()
        for name in preservedNames {
            _ = get(byName: name) // Make sure that all preserved workspaces are "cached"
        }
        workspaceNameToWorkspace = workspaceNameToWorkspace.filter {
            preservedNames.contains($0.value.name) || !$0.value.isEmpty
        }
        return workspaceNameToWorkspace.values.sorted { a, b in a.name < b.name }
    }

    static func get(byName name: String) -> Workspace {
        if let existing = workspaceNameToWorkspace[name] {
            return existing
        } else {
            let workspace = Workspace(name: name)
            workspaceNameToWorkspace[name] = workspace
            return workspace
        }
    }

    static func ==(lhs: Workspace, rhs: Workspace) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

extension NSScreen {
    /// Don't forget that there is always an empty additional "background" workspace on every monitor ``currentEmptyWorkspace``
    var notEmptyWorkspace: Workspace? {
        get {
            if let existing = monitorTopLeftCornerToNotEmptyWorkspace[rect.topLeft] {
                return existing
            }
            // What if monitor configuration changed? (frame.origin is changed)
            rearrangeWorkspacesOnMonitors()
            // Normally, recursion should happen only once more because we must take the value from the cache
            // (Unless, monitor configuration data race happens)
            return self.notEmptyWorkspace
        }
    }

    var workspace: Workspace {
        notEmptyWorkspace ?? currentEmptyWorkspace
    }
}

private func rearrangeWorkspacesOnMonitors() {
    let oldMonitorToWorkspaces: [CGPoint: Workspace?] = monitorTopLeftCornerToNotEmptyWorkspace
    monitorTopLeftCornerToNotEmptyWorkspace = [:]
    let monitors = NSScreen.screens
    let origins = monitors.map { $0.rect.topLeft }.toSet()
    let preservedWorkspaces: [Workspace] = oldMonitorToWorkspaces
            .filter { oldOrigin, oldWorkspace in origins.contains(oldOrigin) }
            .map { $0.value }
            .filterNotNil()
    let lostWorkspaces: [Workspace] = oldMonitorToWorkspaces
            .filter { oldOrigin, oldWorkspace in !origins.contains(oldOrigin) }
            .map { $0.value }
            .filterNotNil()
    var poolOfWorkspaces: [Workspace] =
            Workspace.all.reversed() - (preservedWorkspaces + lostWorkspaces) + lostWorkspaces
    for monitor in monitors {
        let origin = monitor.rect.topLeft
        // If monitors change, most likely we will preserve only the main monitor (It always has (0, 0) origin)
        if let existing = oldMonitorToWorkspaces[origin] {
            monitorTopLeftCornerToNotEmptyWorkspace[origin] = existing
        } else {
            monitorTopLeftCornerToNotEmptyWorkspace[origin] = poolOfWorkspaces.popLast()
        }
    }
}
