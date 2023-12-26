import Common

struct FlattenWorkspaceTreeCommand: Command {
    let info: CmdStaticInfo = FlattenWorkspaceTreeCmdArgs.info

    func _run(_ subject: inout CommandSubject, _ stdout: inout [String]) -> Bool {
        check(Thread.current.isMainThread)
        let workspace = subject.workspace
        let windows = workspace.rootTilingContainer.allLeafWindowsRecursive
        for window in windows {
            window.unbindFromParent()
            window.bind(to: workspace.rootTilingContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        }
        return true
    }
}
