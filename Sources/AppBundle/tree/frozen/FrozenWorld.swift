struct FrozenWorld {
    let workspaces: [FrozenWorkspace]
    let monitors: [FrozenMonitor]
    let windowIds: Set<UInt32>

    init(workspaces: [FrozenWorkspace], monitors: [FrozenMonitor]) {
        self.workspaces = workspaces
        self.monitors = monitors
        self.windowIds = workspaces.flatMap { collectAllWindowIds(workspace: $0) }.toSet()
    }
}

private func collectAllWindowIds(workspace: FrozenWorkspace) -> [UInt32] {
    workspace.floatingWindows.map { $0.id } +
        workspace.macosUnconventionalWindows.map { $0.id } +
        collectAllWindowIdsRecursive(node: .container(workspace.rootTilingNode))
}

private func collectAllWindowIdsRecursive(node: FrozenTreeNode) -> [UInt32] {
    switch node {
        case .window(let w): [w.id]
        case .container(let c):
            c.children.reduce(into: [UInt32]()) { partialResult, elem in
                partialResult += collectAllWindowIdsRecursive(node: elem)
            }
    }
}
