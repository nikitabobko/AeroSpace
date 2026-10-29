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
