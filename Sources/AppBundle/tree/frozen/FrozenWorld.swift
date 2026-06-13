struct FrozenWorld {
    let workspaces: [FrozenWorkspace]
    let monitors: [FrozenMonitor]
    let windowIds: Set<UInt32>
}

@MainActor
func collectAllWindowIds(workspace: Workspace) -> [UInt32] {
    workspace.floatingWindows.map { $0.windowId } +
        workspace.macOsNativeFullscreenWindowsContainer.children.map { ($0 as! Window).windowId } +
        workspace.macOsNativeHiddenAppsWindowsContainer.children.map { ($0 as! Window).windowId } +
        collectAllWindowIdsRecursive(workspace.rootTilingContainer)
}

private func collectAllWindowIdsRecursive(_ node: TreeNode) -> [UInt32] {
    switch node.nodeCases {
        case .macosFullscreenWindowsContainer,
             .macosHiddenAppsWindowsContainer,
             .macosMinimizedWindowsContainer,
             .macosPopupWindowsContainer,
             .floatingWindowsContainer,
             .workspace: []
        case .tilingContainer(let c):
            c.children.reduce(into: [UInt32]()) { partialResult, elem in
                partialResult += collectAllWindowIdsRecursive(elem)
            }
        case .window(let w): [w.windowId]
    }
}
