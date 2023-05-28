import Foundation

// todo make it configurable
// todo make default choice
func createDefaultWorkspaceContainer() -> Container {
    if monitorWidth > monitorHeight {
        return VStackContainer()
    } else {
        return HStackContainer()
    }
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
    var floatingWindows: [Window] = []
    var rootContainer: Container = createDefaultWorkspaceContainer()

    init(name: String) {
        self.name = name
    }
}

extension Workspace {
    var allWindows: [Window] {
        floatingWindows + rootContainer.allWindows
    }
}
