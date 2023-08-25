import Foundation

/// It's one of the most important function of the whole application.
/// The function is called as a feedback response on every user input
func refresh() {
    debug("refresh")
    refreshWorkspaces()
    materializeWorkspaces()
    // Detect new windows and layout them
    let _ = getWindowsVisibleOnAllMonitors()

    updateLastActiveWindow()

    MacApp.garbageCollectTerminatedApps()
    Workspace.garbageCollectUnusedWorkspaces()
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
    if let focusedWindow = NSWorkspace.shared.menuBarOwningApplication?.macApp?.focusedWindow {
        let focusedWorkspace = focusedWindow.workspace
        monitorTopLeftCornerToNotEmptyWorkspace[focusedWorkspace.assignedMonitorRect.topLeftCorner] = focusedWorkspace
        ViewModel.shared.focusedWorkspaceTrayText = focusedWorkspace.name
    } else {
        ViewModel.shared.focusedWorkspaceTrayText = currentEmptyWorkspace.name
    }
}

private func materializeWorkspaces() {
    for workspace in Workspace.all {
        if workspace.isVisible {
            workspace.allWindowsRecursive.forEach { $0.unhideViaEmulation() }
        } else {
            workspace.allWindowsRecursive.forEach { $0.hideViaEmulation() }
        }
    }
}

private func getWindowsVisibleOnAllMonitors() -> [MacWindow] {
    NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .flatMap { $0.macApp?.windowsVisibleOnAllMonitors ?? [] }
}
