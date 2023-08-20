import Foundation

class ViewModel: ObservableObject {
    static let shared = ViewModel()

    private init() {
    }

    @Published var focusedWorkspaceTrayText: String = currentEmptyWorkspace.name

    func switchToWorkspace(_ newWorkspace: Workspace) {
        // todo
        //for window in focusedWorkspaceTrayText.allWindows ?? [] {
        //    window.hideEmulation()
        //}
        //for window in newWorkspace.allWindowsRecursive {
        //    window.unhideByEmulation()
        //}
        //let focusedMonitor = NSScreen.focusedMonitorOrNilIfDesktop ?? NSScreen.main
        //if let focusedMonitor, let alreadyAllocatedOn = newWorkspace.monitorIfWorkspaceVisibleOrNil {
        //    // todo .frame -> .rect
        //    if alreadyAllocatedOn.frame.origin != focusedMonitor.frame.origin {
        //        newWorkspace.moveTo(monitor: focusedMonitor)
        //    }
        //}
        //focusedWorkspaceTrayText = newWorkspace
        //// todo change active app when workspace is empty? Hahaha :facepalm:
    }

    func updateTrayText() {
        let workspace = NSScreen.focusedMonitorOrNilIfDesktop?.notEmptyWorkspace ?? currentEmptyWorkspace
        focusedWorkspaceTrayText = workspace.name
    }
}
