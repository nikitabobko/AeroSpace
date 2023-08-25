import Foundation

/// It's one of the most important function of the whole application.
/// The function is called as a feedback response on every user input
func refresh() {
    debug("refresh")
    refreshWorkspaces()
    //ViewModel.shared.updateTrayText()
    let visibleWindows = getWindowsVisibleOnAllMonitors()
    // Hide windows that were manually unhidden by user
    visibleWindows.filter { $0.isHiddenViaEmulation }.forEach { $0.hideViaEmulation() }
    //layoutNewWindows(visibleWindows: visibleWindows)

    updateLastActiveWindow()

    Workspace.garbageCollectUnusedWorkspaces()
    MacApp.garbageCollectTerminatedApps()
}

func updateLastActiveWindow() {
    guard let window = NSWorkspace.shared.menuBarOwningApplication?.macApp?.focusedWindow else { return }
    window.workspace.lastActiveWindow = window
}

func switchToWorkspace(_ workspace: Workspace) {
    refresh()
    if let window = workspace.lastActiveWindow ?? workspace.anyChildWindowRecursive {
        window.activate()
    } else {
        precondition(workspace.isEffectivelyEmpty)
        // It's the only place in the app where I allow myself to use NSScreen.main.
        // This function isn't invoked from callbacks that's why .main should be fine
        guard let activeMonitor = NSScreen.focusedMonitorOrNilIfDesktop ?? NSScreen.main else { return }
        monitorTopLeftCornerToNotEmptyWorkspace[activeMonitor.rect.topLeftCorner] = nil
        currentEmptyWorkspace = workspace
    }
    refresh()
}

private func refreshWorkspaces() {
    //focusedWorkspaceTrayText =
    //        (NSScreen.focusedMonitorOrNilIfDesktop?.notEmptyWorkspace ?? currentEmptyWorkspace).name
    if let focusedWindow = NSWorkspace.shared.menuBarOwningApplication?.macApp?.focusedWindow {
        let focusedWorkspace = focusedWindow.workspace
        monitorTopLeftCornerToNotEmptyWorkspace[focusedWorkspace.assignedMonitorRect.topLeftCorner] = focusedWorkspace
        ViewModel.shared.focusedWorkspaceTrayText = focusedWorkspace.name
    } else {
        ViewModel.shared.focusedWorkspaceTrayText = currentEmptyWorkspace.name
    }
}

//private func layoutNewWindows(visibleWindows: [MacWindow]) {
//    for newWindow: MacWindow in visibleWindows.toSet().subtracting(Workspace.all.flatMap { $0.allWindowsRecursive }) {
//        if let workspace: Workspace = newWindow.monitorApproximation?.notEmptyWorkspace {
//            debug("New window \(newWindow.title) layoted on workspace \(workspace.name)")
//            workspace.add(window: newWindow)
//        }
//    }
//}

private func getWindowsVisibleOnAllMonitors() -> [MacWindow] {
    NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .flatMap { $0.macApp?.visibleWindowsOnAllMonitors ?? [] }
}
