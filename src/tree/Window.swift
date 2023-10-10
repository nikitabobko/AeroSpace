class Window: TreeNode, Hashable {
    let windowId: UInt32
    override var parent: TreeNode { super.parent ?? errorT("Windows always have parent") }
    var parentOrNilForTests: TreeNode? { super.parent }
    var lastLayoutedRect: Rect? = nil

    init(id: UInt32, parent: TreeNode, adaptiveWeight: CGFloat, index: Int) {
        self.windowId = id
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(windowId)
    }

    var title: String? { error("Not implemented") }

    func setSize(_ size: CGSize) { error("Not implemented") }

    func setTopLeftCorner(_ point: CGPoint) { error("Not implemented") }
}

extension Window {
    var isFloating: Bool { parent is Workspace }

    @discardableResult
    func bindAsFloatingWindowTo(workspace: Workspace) -> PreviousBindingData? {
        parent != workspace ? bindTo(parent: workspace, adaptiveWeight: WEIGHT_AUTO) : nil
    }

    var ownIndex: Int { parent.children.firstIndex(of: self)! }
}

@inlinable func windowsCantHaveChildren() -> Never {
    error("Windows are leaf nodes. They can't have children")
}
