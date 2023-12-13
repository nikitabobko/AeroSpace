struct WorkspaceCommand : Command {
    let args: WorkspaceCmdArgs

    func _run(_ subject: inout CommandSubject, _ index: Int, _ commands: [any Command]) {
        check(Thread.current.isMainThread)
        let workspaceName: String
        switch args.target {
        case .next:
            fallthrough
        case .prev:
            guard let workspace = getNextPrevWorkspace(current: subject.workspace, next: args.target == .next) else { return }
            workspaceName = workspace.name
        case .workspaceName(let _workspaceName):
            workspaceName = _workspaceName
        }
        let workspace = Workspace.get(byName: workspaceName)
        // todo drop anyLeafWindowRecursive. It must not be necessary
        if let window = workspace.mostRecentWindow ?? workspace.anyLeafWindowRecursive { // switch to not empty workspace
            subject = .window(window)
        } else { // switch to empty workspace
            check(workspace.isEffectivelyEmpty)
            subject = .emptyWorkspace(workspaceName)
        }
        check(workspace.monitor.setActiveWorkspace(workspace))
        focusedWorkspaceName = workspace.name
    }
}

func getNextPrevWorkspace(current: Workspace, next: Bool) -> Workspace? {
    let workspaces: [Workspace] = Workspace.all.toSet().union([current]).sortedBy { $0.name }
    guard let index = workspaces.firstIndex(of: current) else { error("Impossible") }
    guard let workspace = workspaces.getOrNil(atIndex: next ? index + 1 : index - 1) else { return nil }
    return workspace
}
