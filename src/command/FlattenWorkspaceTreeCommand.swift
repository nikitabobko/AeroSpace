struct FlattenWorkspaceTreeCommand: Command {
    func runWithoutLayout(state: inout FocusState) {
        check(Thread.current.isMainThread)
        let workspace = state.workspace
        let windows = workspace.rootTilingContainer.allLeafWindowsRecursive
        for window in windows {
            window.unbindFromParent()
            window.bind(to: workspace.rootTilingContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        }
    }
}
