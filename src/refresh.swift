import Foundation

/**
 It's one of the most important function of the whole application.
 The function is called as a feedback response on every user input
 */
func refresh() {
    if let monitor = NSScreen.focusedMonitor {
        // todo doesn't work if the window is moved from one monitor to another
        ViewModel.shared.focusWorkspaceOnDifferentMonitor(Workspace.get(byMonitor: monitor).name)
    }
    let visibleWindows = windowsOnActiveMacOsSpaces()
    // Hide windows that were manually unhidden by user
    visibleWindows.filter { $0.isHiddenEmulation }.forEach { $0.hideEmulation() }
    layoutNewWindows(visibleWindows: visibleWindows)
}

private func layoutNewWindows(visibleWindows: [MacWindow]) {
    let currentWorkspace = getWorkspace(byName: ViewModel.shared.currentWorkspaceName)
    for newWindow in Set(visibleWindows).subtracting(allWorkspaces.flatMap { $0.allWindows }) {
        print("New window \(newWindow.title) layoted on workspace \(currentWorkspace.name)")
        currentWorkspace.add(window: newWindow)
    }
}

private func windowsOnActiveMacOsSpaces() -> [MacWindow] {
    NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .flatMap { MacApp.get($0).windowsOnActiveMacOsSpaces }
}
