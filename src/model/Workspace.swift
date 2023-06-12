import Foundation

// todo make it configurable
// todo make default choice
private func createDefaultWorkspaceContainer() -> Container {
    guard let monitorFrame = NSScreen.focusedMonitor?.frame else { return HStackContainer() }
    return monitorFrame.width > monitorFrame.height ? VStackContainer() : HStackContainer()
}
// todo fetch from real settings
let initialWorkspaceName = settings[0].id

// todo minor: clean this "cache"
private var workspaceNameToWorkspace: [String: Workspace] = [:]
private var monitorOriginToWorkspace: [CGPoint: Workspace] = [:]

class Workspace: Hashable {
    let name: String
    var floatingWindows: Set<MacWindow> = []
    var rootContainer: Container = createDefaultWorkspaceContainer()

    private init(name: String) {
        self.name = name
    }

    func add(window: MacWindow) {
        floatingWindows.insert(window)
    }

    func remove(window: MacWindow) {
        floatingWindows.remove(window)
    }

    // todo Implement properly
    func moveTo(monitor: NSScreen) {
        for window in floatingWindows {
            window.setPosition(monitor.visibleFrame.origin)
        }
    }

    static var all: some Collection<Workspace> { workspaceNameToWorkspace.values }

    static func get(byName name: String) -> Workspace {
        if let existing = workspaceNameToWorkspace[name] {
            return existing
        } else {
            let workspace = Workspace(name: name)
            workspaceNameToWorkspace[name] = workspace
            return workspace
        }
    }

    static func get(byMonitor monitor: NSScreen) -> Workspace {
        if let existing = monitorOriginToWorkspace[monitor.frame.origin] {
            return existing
        }
        let oldMonitorToWorkspace: [CGPoint: Workspace] = monitorOriginToWorkspace
        monitorOriginToWorkspace = [:]
        let origins = NSScreen.screens.map { $0.frame.origin }.toSet()
        var notAssignedWorkspaces: [Workspace] =
                settings.map { Workspace.get(byName: $0.id) }
                        .toSet()
                        .subtracting(oldMonitorToWorkspace.values) +
                        oldMonitorToWorkspace.filter { oldOrigin, oldWorkspace in !origins.contains(oldOrigin) }
                                .map { _, workspace -> Workspace in workspace }

        for monitor in NSScreen.screens {
            let origin = monitor.frame.origin
            // If monitors change, most likely we will preserve only the main monitor (It always has (0, 0) origin)
            if let existing = oldMonitorToWorkspace[origin] {
                monitorOriginToWorkspace[origin] = existing
            } else {
                monitorOriginToWorkspace[origin] = notAssignedWorkspaces.popLast()
                        // todo show user friendly dialog
                        ?? errorT("""
                                  Not enough number of workspaces for the number of monitors. 
                                  Please add more workspaces to the config
                                  """)
            }
        }
        // Normally, recursion should happen only once more (Unless, NSScreen data race happens)
        return get(byMonitor: monitor)
    }

    static func ==(lhs: Workspace, rhs: Workspace) -> Bool {
        lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

extension Workspace {
    var allWindows: [MacWindow] { floatingWindows + rootContainer.allWindows }

    var monitor: NSScreen? { NSScreen.screens.first { Workspace.get(byMonitor: $0) === self } }

    var isVisible: Bool { monitor != nil }
}
