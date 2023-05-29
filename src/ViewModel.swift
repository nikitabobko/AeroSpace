import Foundation

class ViewModel: ObservableObject {
    static let shared = ViewModel()

    @Published private(set) var currentWorkspaceName: String = initialWorkspaceName

    func changeWorkspace(_ newWorkspace: String) {
        refresh()
        for window in getWorkspace(name: currentWorkspaceName).allWindows {
            window.hideEmulation()
        }
        for window in getWorkspace(name: newWorkspace).allWindows {
            window.unhideEmulation()
        }
        currentWorkspaceName = newWorkspace
    }
}
