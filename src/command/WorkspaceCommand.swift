struct WorkspaceCommand : Command {
    let workspaceName: String

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        let workspace = Workspace.get(byName: workspaceName)
        debug("Switch to workspace: \(workspace.name)")
        if let window = workspace.mruWindows.mostRecent ?? workspace.anyLeafWindowRecursive { // switch to not empty workspace
            window.focus()
            // The switching itself will be done by refreshWorkspaces and layoutWorkspaces later in refresh
        } else { // switch to empty workspace
            precondition(workspace.isEffectivelyEmpty)
            // It's the only place in the app where I allow myself to use NSScreen.main.
            // This function isn't invoked from callbacks that's why .main should be fine
            if let focusedMonitor = NSScreen.focusedMonitorOrNilIfDesktop ?? NSScreen.main?.monitor {
                focusedMonitor.setActiveWorkspace(workspace)
            }
            WorkspaceCommand.defocusAllWindows()
        }
        debug("End switch to workspace: \(workspace.name)")
    }

    static func switchToWorkspace(_ workspace: Workspace) async {
        await WorkspaceCommand(workspaceName: workspace.name).run()
    }

    private static func defocusAllWindows() {
        // Since AeroSpace doesn't show any windows, focusing AeroSpace defocuses all windows
        let current = NSRunningApplication.current
        current.activate(options: .activateIgnoringOtherApps)
        setFocusedAppForCurrentRefreshSession(app: current)
    }
}
