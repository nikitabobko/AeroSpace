class Window: TreeNode, Hashable {
    let windowId: UInt32

    init(id: UInt32, parent: TreeNode, adaptiveWeight: CGFloat) {
        self.windowId = id
        super.init(parent: parent, adaptiveWeight: adaptiveWeight)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(windowId)
    }
}
