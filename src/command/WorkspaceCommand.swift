struct WorkspaceCommand : Command {
    let workspaceName: String

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        let workspace = Workspace.get(byName: workspaceName)
        debug("Switch to workspace: \(workspace.name)")
        if let window = workspace.mostRecentWindow ?? workspace.anyLeafWindowRecursive { // switch to not empty workspace
            workspace.focusMruReversedRecursive()
            // Technically, it must not be necessary. But this way, it's more chances
            // that the correct window will end up focused at the end
            window.focus()
            // The switching itself will be done by refreshWorkspaces and layoutWorkspaces later in refresh
        } else { // switch to empty workspace
            precondition(workspace.isEffectivelyEmpty)
            // It's the only place in the app where I allow myself to use NSScreen.main.
            // This function isn't invoked from callbacks that's why .main should be fine
            if let focusedMonitor = NSScreen.focusedMonitorOrNilIfDesktop ?? NSScreen.main?.monitor {
                focusedMonitor.setActiveWorkspace(workspace)
            }
            defocusAllWindows()
        }
        debug("End switch to workspace: \(workspace.name)")
    }

    static func switchToWorkspace(_ workspace: Workspace) async {
        await WorkspaceCommand(workspaceName: workspace.name).run()
    }
}

private extension TreeNode {
    // todo Switch between workspaces can happen via cmd+tab. Maybe this functionality must be moved to refresh
    func focusMruReversedRecursive() {
        if let window = self as? Window {
            window.focus()
        }
        for child in mostRecentChildren.reversed() {
            child.focusMruReversedRecursive()
        }
    }
}