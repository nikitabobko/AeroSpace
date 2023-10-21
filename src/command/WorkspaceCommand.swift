struct WorkspaceCommand : Command {
    let workspaceName: String

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        let workspace = Workspace.get(byName: workspaceName)
        if let window = workspace.mostRecentWindow { // switch to not empty workspace
            // Make sure that stack of windows is correct from macOS perspective (important for closing windows)
            // Alternative: focus mru window in destroyedObs (con: possible flickering when windows are closed,
            // because focusedWindow is source of truth for workspaces)
            if !workspace.isVisible { // Only do it for invisible workspaces to avoid flickering when switch to already visible workspace
                workspace.focusMruReversedRecursive()
            }
            focusedWorkspaceSourceOfTruth = .macOs
            window.focus()
            // The switching itself will be done by refreshWorkspaces and layoutWorkspaces later in refresh
        } else { // switch to empty workspace
            precondition(workspace.isEffectivelyEmpty)
            workspace.monitor.setActiveWorkspace(workspace)
            focusedWorkspaceName = workspace.name
            focusedWorkspaceSourceOfTruth = .ownModel
        }
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