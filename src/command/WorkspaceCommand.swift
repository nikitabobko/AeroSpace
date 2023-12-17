import Common

struct WorkspaceCommand : Command {
    let info: CmdStaticInfo = WorkspaceCmdArgs.info
    let args: WorkspaceCmdArgs

    func _run(_ subject: inout CommandSubject, _ stdout: inout String) -> Bool {
        check(Thread.current.isMainThread)
        let workspaceName: String
        switch args.target {
        case .next:
            fallthrough
        case .prev:
            guard let workspace = getNextPrevWorkspace(current: subject.workspace, target: args.target) else { return false }
            workspaceName = workspace.name
        case .workspaceName(let _workspaceName, let autoBackAndForth):
            workspaceName = _workspaceName
            if autoBackAndForth && subject.workspace.name == workspaceName {
                return WorkspaceBackAndForthCommand().run(&subject, &stdout)
            }
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
        return true
    }
}

func getNextPrevWorkspace(current: Workspace, target: WorkspaceTarget) -> Workspace? {
    let next: Bool
    let wrapAround: Bool
    switch target {
    case .next(let _wrapAround):
        next = true
        wrapAround = _wrapAround
    case .prev(let _wrapAround):
        next = false
        wrapAround = _wrapAround
    case .workspaceName(_):
        error("Invalid argument \(target)")
    }
    let workspaces: [Workspace] = Workspace.all.toSet().union([current]).sortedBy { $0.name }
    guard let index = workspaces.firstIndex(of: current) else { error("Impossible") }
    let workspace: Workspace?
    if wrapAround {
        workspace = workspaces.get(wrappingIndex: next ? index + 1 : index - 1)
    } else {
        workspace = workspaces.getOrNil(atIndex: next ? index + 1 : index - 1)
    }
    return workspace
}
