import Foundation

// todo make it configurable
// todo make default choice
func createDefaultWorkspaceContainer() -> Container {
    guard let monitorFrame = NSScreen.focusedMonitor?.frame else { return HStackContainer() }
    return monitorFrame.width > monitorFrame.height ? VStackContainer() : HStackContainer()
}
// todo fetch from real settings
let initialWorkspaceName = settings[0].id

var workspaces: [String: Workspace] = [:]

func getWorkspace(name: String) -> Workspace {
    if let existing = workspaces[name] {
        return existing
    } else {
        let workspace = Workspace(name: name)
        workspaces[name] = workspace
        return workspace
    }
}

class Workspace {
    let name: String
    var floatingWindows: [MacWindow] = []
    var rootContainer: Container = createDefaultWorkspaceContainer()

    init(name: String) {
        self.name = name
    }

    func layout(window: MacWindow) {
        floatingWindows.append(window)
    }
}

extension Workspace {
    var allWindows: [MacWindow] {
        floatingWindows + rootContainer.allWindows
    }
}
