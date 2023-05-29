import Foundation

// todo make it configurable
// todo make default choice
private func createDefaultWorkspaceContainer() -> Container {
    guard let monitorFrame = NSScreen.focusedMonitor?.frame else { return HStackContainer() }
    return monitorFrame.width > monitorFrame.height ? VStackContainer() : HStackContainer()
}
// todo fetch from real settings
let initialWorkspaceName = settings[0].id

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
        let monitorWorkspaces: [CGPoint: Workspace] = monitorOriginToWorkspace
        monitorOriginToWorkspace = [:]
        let origins = NSScreen.screens.map { $0.frame.origin }.toSet()
        var notAssignedWorkspaces: [Workspace] =
                monitorWorkspaces.filter { oldOrigin, oldWorkspace in !origins.contains(oldOrigin) }
                        .map { _, workspace -> Workspace in workspace }
                        + settings.map { Workspace.get(byName: $0.id) }.toSet()
                            .subtracting(monitorWorkspaces.values)

        for monitor in NSScreen.screens {
            let origin = monitor.frame.origin
            if let existing = monitorWorkspaces[origin] {
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
}
