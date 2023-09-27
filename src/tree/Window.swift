class Window: TreeNode, Hashable {
    let windowId: UInt32

    init(id: UInt32, parent: TreeNode, adaptiveWeight: CGFloat) {
        self.windowId = id
        super.init(parent: parent, adaptiveWeight: adaptiveWeight)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(windowId)
    }

    var title: String? { error("Not implemented") }
}

extension Window {
    var isFloating: Bool { parent is Workspace }

    @discardableResult
    func bindAsFloatingWindowTo(workspace: Workspace) -> PreviousBindingData? {
        parent != workspace ? bindTo(parent: workspace, adaptiveWeight: FLOATING_ADAPTIVE_WEIGHT) : nil
    }
}
