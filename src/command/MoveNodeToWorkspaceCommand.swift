import Common

struct MoveNodeToWorkspaceCommand: Command {
    let info: CmdStaticInfo = MoveNodeToWorkspaceCmdArgs.info
    let args: MoveNodeToWorkspaceCmdArgs

    func _run(_ subject: inout CommandSubject, stdin: String, stdout: inout [String]) -> Bool {
        guard let focused = subject.windowOrNil else {
            stdout.append(noWindowIsFocused)
            return false
        }
        let preserveWorkspace = focused.workspace
        let targetWorkspace: Workspace
        switch args.target {
        case .next:
            fallthrough
        case .prev:
            guard let workspace = getNextPrevWorkspace(current: subject.workspace, target: args.target) else { return false }
            targetWorkspace = workspace
        case .workspaceName(let name, let autoBackAndForth):
            check(!autoBackAndForth)
            targetWorkspace = Workspace.get(byName: name)
        }
        if preserveWorkspace == targetWorkspace {
            return true
        }
        let targetContainer: NonLeafTreeNode = focused.isFloating ? targetWorkspace : targetWorkspace.rootTilingContainer
        focused.unbindFromParent()
        focused.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        return WorkspaceCommand(args: WorkspaceCmdArgs(target: .workspaceName(name: preserveWorkspace.name, autoBackAndForth: false)))
            .run(&subject, stdout: &stdout)
    }
}
