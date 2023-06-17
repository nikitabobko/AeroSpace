import Foundation

class ViewModel: ObservableObject {
    static let shared = ViewModel()

    private init() {
    }

    /**
     This value changes when active monitor changes. `nil` when the the active app doesn't have any windows
     */
    @Published private(set) var focusedWorkspace: Workspace? = nil
    /**
     Use ``focusedWorkspace`` if possible. But ``focusedWorkspace`` isn't reliable. When macOS desktop is selected, it's
     hard to know what monitor is active (see ``NSScreen.focusedMonitor``). If you need not nullable approximation (for
     example, you need to layout new windows) then you can use this approximation
     */
     // todo unused?
//    var focusedWorkspaceApproximation: Workspace = Workspace.get(byName: settings[0].id)

    // todo use fake anchor windows to switch the focus?
    //  https://github.com/bigbearlabs/SpaceSwitcher/blob/master/SpaceSwitcher/SpaceSwitcher.swift
    func switchToWorkspace(_ newWorkspace: Workspace) {
        refresh()
        for window in focusedWorkspace?.allWindows ?? [] {
            window.hideEmulation()
        }
        for window in newWorkspace.allWindows {
            window.unhideEmulation()
        }
        let focusedMonitor = NSScreen.focusedMonitor ?? NSScreen.main
        if let focusedMonitor, let alreadyAllocatedOn = newWorkspace.monitor {
            if alreadyAllocatedOn.frame.origin != focusedMonitor.frame.origin {
                newWorkspace.moveTo(monitor: focusedMonitor)
            }
        }
        focusedWorkspace = newWorkspace
        // todo change active app when workspace is empty? Hahaha :facepalm:
    }

    func updateFocusedMonitor() {
        let workspace: Workspace? = NSScreen.focusedMonitor.map { Workspace.get(byMonitor: $0) }
        focusedWorkspace = workspace
//        if let workspace {
//            focusedWorkspaceApproximation = workspace
//        }
    }
}
