import Foundation

/**
 It's one of the most important function of the whole application. Call it as often as possible
 */
func refresh() {
    let allWindows = windowsOnActiveMacOsSpaces()
    // Hide windows that were manually unhidden by user
    allWindows.filter { $0.isHiddenEmulation }.forEach { $0.hideEmulation() }
    layoutNewWindows(allWindows: allWindows)
}

private func layoutNewWindows(allWindows: [MacWindow]) {
    let currentWorkspace = getWorkspace(name: ViewModel.shared.currentWorkspaceName)
    for newWindow in Set(allWindows).subtracting(workspaces.values.flatMap { $0.allWindows }) {
        print("New window \(newWindow.title) layoted on workspace \(currentWorkspace.name)")
        currentWorkspace.floatingWindows.append(newWindow)
    }
}

private func windowsOnActiveMacOsSpaces() -> [MacWindow] {
    NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .flatMap { MacApp.get($0).windowsOnActiveMacOsSpaces }
}
