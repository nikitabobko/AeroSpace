import Foundation

class ViewModel: ObservableObject {
    static let shared = ViewModel()

    private init() {
    }

    @Published var focusedWorkspaceTrayText: String = currentEmptyWorkspace.name // settings.first?.name ?? "W: 1"

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
        //    if alreadyAllocatedOn.rect.topLeft != focusedMonitor.rect.topLeft {
        //        newWorkspace.moveTo(monitor: focusedMonitor)
        //    }
        //}
        //focusedWorkspaceTrayText = newWorkspace
        //// todo change active app when workspace is empty? Hahaha :facepalm:
    }

    func updateTrayText() {
        focusedWorkspaceTrayText =
                (NSWorkspace.shared.menuBarOwningApplication?.macApp.focusedWindow?.workspace ?? currentEmptyWorkspace).name
        //focusedWorkspaceTrayText =
        //        (NSScreen.focusedMonitorOrNilIfDesktop?.notEmptyWorkspace ?? currentEmptyWorkspace).name
    }
}

