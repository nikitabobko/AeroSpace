struct FlattenWorkspaceTreeCommand: Command {
    func runWithoutRefresh() {
        check(Thread.current.isMainThread)
        guard let currentWindow = focusedWindowOrEffectivelyFocused else { return }
        let workspace = currentWindow.workspace
        let windows = workspace.rootTilingContainer.allLeafWindowsRecursive
        for window in windows {
            window.unbindFromParent()
            window.bindTo(parent: workspace.rootTilingContainer, adaptiveWeight: 1)
        }
    }
}
