import Foundation

// todo make it configurable
// todo make default choice
func createDefaultWorkspaceContainer() -> Container {
    if monitorWidth > monitorHeight {
        return ColumnContainer()
    } else {
        return RowContainer()
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
    var root: Container = createDefaultWorkspaceContainer()

    init(name: String) {
        self.name = name
    }
}

extension Workspace {
    var allWindows: [Window] {
        get {
            floatingWindows + root.allWindows
        }
    }
}