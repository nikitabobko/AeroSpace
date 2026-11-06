import Common

struct FrozenWorld {
    let monitors: [FrozenMonitor]
    let windowIds: Set<OpaqueWindowId>
}

func collectAllWindowIdsRecursive(_ node: TreeNode) -> [OpaqueWindowId] {
    if let window = node as? Window { return [window.windowId] }
    var result = [OpaqueWindowId]()
    for child in node.children {
        result += collectAllWindowIdsRecursive(child)
    }
    return result
}

/// Replaying markAsMostRecentChild over the returned windows in order rebuilds the MRU order of every node in the subtree
@MainActor func mruReplayOrder(_ node: TreeNode) -> [OpaqueWindowId] {
    if let window = node as? Window { return [window.windowId] }
    let mru = Array(node._mruChildren) // Most recent first
    let neverMarked = node.children.filter { child in !mru.contains { $0 === child } }
    return (neverMarked + mru.reversed()).flatMap { mruReplayOrder($0) }
}
