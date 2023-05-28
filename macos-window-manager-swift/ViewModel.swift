import Foundation

class ViewModel: ObservableObject {
    static let shared = ViewModel()

    @Published private(set) var currentWorkspaceName: String = initialWorkspaceName

    func changeWorkspace(_ newWorkspace: String) {
        for window in getWorkspace(name: currentWorkspaceName).allWindows {
            window.hide()
        }
        for window in getWorkspace(name: newWorkspace).allWindows {
            window.unhide()
        }
        currentWorkspaceName = newWorkspace
    }
}
