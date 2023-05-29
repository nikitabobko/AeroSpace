import Foundation

class ViewModel: ObservableObject {
    static let shared = ViewModel()

    /**
     This value changes when active monitor changes
     */
     // todo keep real Workspace object here
    @Published private(set) var currentWorkspaceName: String = initialWorkspaceName

    func changeWorkspace(_ newWorkspace: String) {
        // todo what if the newWorkspace is already active but on different monitor?
        refresh()
        for window in getWorkspace(byName: currentWorkspaceName).allWindows {
            window.hideEmulation()
        }
        for window in getWorkspace(byName: newWorkspace).allWindows {
            window.unhideEmulation()
        }
        currentWorkspaceName = newWorkspace
    }

    func focusWorkspaceOnDifferentMonitor(_ workspace: String) {
        currentWorkspaceName = workspace
    }
}
