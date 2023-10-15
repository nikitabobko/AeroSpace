struct WorkspaceCommand : Command {
    let workspaceName: String

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        let workspace = Workspace.get(byName: workspaceName)
        debug("Switch to workspace: \(workspace.name)")
        if let window = workspace.mostRecentWindow ?? workspace.anyLeafWindowRecursive { // switch to not empty workspace
            // Make sure that stack of windows is correct from macOS perspective (important for closing windows)
            // Alternative: focus mru window in destroyedObs (con: possible flickering when windows are closed,
            // because focusedWindow is source of truth for workspaces)
            if !workspace.isVisible { // Only do it for invisible workspaces to avoid flickering when switch to already visible workspace
                workspace.focusMruReversedRecursive()
            }
            window.focus()
            // The switching itself will be done by refreshWorkspaces and layoutWorkspaces later in refresh
        } else { // switch to empty workspace
            precondition(workspace.isEffectivelyEmpty)
            // It's fine to call Unsafe from here because commands are not invoked from callbacks,
            // the callbacks are triggered by user
            if let focusedMonitor = focusedMonitorOrNilIfDesktop ?? focusedMonitorUnsafe {
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