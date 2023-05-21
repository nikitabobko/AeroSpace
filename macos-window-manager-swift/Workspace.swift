import Foundation

// todo make it configurable
// todo make default choice
let defaultWorkspaceContainer = ColumnContainer()
// todo fetch from bindings
let initialWorkspace = settings[0].id

//var currentWorkspace = initialWorkspace

private var workspaces: [String: Workspace] = [:]

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
    var root: Container = defaultWorkspaceContainer

    init(name: String) {
        self.name = name
    }
}
