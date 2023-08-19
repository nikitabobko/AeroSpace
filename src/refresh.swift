import Foundation

/// It's one of the most important function of the whole application.
/// The function is called as a feedback response on every user input
func refresh() {
    ViewModel.shared.updateTrayText()
    let visibleWindows = windowsOnActiveMacOsSpaces()
    // Hide windows that were manually unhidden by user
    visibleWindows.filter { $0.isHiddenEmulation }.forEach { $0.hideByEmulation() }
    layoutNewWindows(visibleWindows: visibleWindows)
}

private func layoutNewWindows(visibleWindows: [MacWindow]) {
    for newWindow: MacWindow in visibleWindows.toSet().subtracting(Workspace.all.flatMap { $0.allWindowsRecursive }) {
        if let workspace: Workspace = newWindow.monitorApproximation?.notEmptyWorkspace {
            debug("New window \(newWindow.title) layoted on workspace \(workspace.name)")
            workspace.add(window: newWindow)
        }
    }
}

private func windowsOnActiveMacOsSpaces() -> [MacWindow] {
    NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .flatMap { $0.macApp.windowsOnActiveMacOsSpaces }
}
