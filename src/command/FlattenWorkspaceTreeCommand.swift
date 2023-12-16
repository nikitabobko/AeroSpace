struct FlattenWorkspaceTreeCommand: Command {
    func _run(_ subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        let workspace = subject.workspace
        let windows = workspace.rootTilingContainer.allLeafWindowsRecursive
        for window in windows {
            window.unbindFromParent()
            window.bind(to: workspace.rootTilingContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        }
    }
}
