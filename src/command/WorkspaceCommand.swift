struct WorkspaceCommand : Command {
    let workspaceName: String

    func runWithoutLayout() {
        check(Thread.current.isMainThread)
        let workspace = Workspace.get(byName: workspaceName)
        // todo drop anyLeafWindowRecursive. It must not be necessary
        if let window = workspace.mostRecentWindow ?? workspace.anyLeafWindowRecursive { // switch to not empty workspace
            if !workspace.isVisible { // Only do it for invisible workspaces to avoid flickering when switch to already visible workspace
                // Make sure that stack of windows is correct from macOS perspective (important for closing windows)
                // Alternative: focus mru window in destroyedObs (con: flickering when windows are closed, because
                // focusedWindow is source of truth for workspaces)
                workspace.focusMruReversedRecursive() // todo try to reduce flickering
            }
            focusedWorkspaceSourceOfTruth = .macOs
            window.focus()
        } else { // switch to empty workspace
            check(workspace.isEffectivelyEmpty)
            focusedWorkspaceSourceOfTruth = .ownModel
        }
        check(workspace.monitor.setActiveWorkspace(workspace))
        focusedWorkspaceName = workspace.name
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