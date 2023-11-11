class Window: TreeNode, Hashable {
    let windowId: UInt32
    let app: AeroApp
    override var parent: NonLeafTreeNode { super.parent ?? errorT("Windows always have parent") }
    var parentOrNilForTests: NonLeafTreeNode? { super.parent }
    var lastFloatingSize: CGSize?
    var isFullscreen: Bool = false

    init(id: UInt32, _ app: AeroApp, lastFloatingSize: CGSize?, parent: NonLeafTreeNode, adaptiveWeight: CGFloat, index: Int) {
        self.windowId = id
        self.app = app
        self.lastFloatingSize = lastFloatingSize
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @discardableResult
    func close() -> Bool {
        error("Not implemented")
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(windowId)
    }

    func getTopLeftCorner() -> CGPoint? { error("Not implemented") }
    func getSize() -> CGSize? { error("Not implemented") }
    var title: String? { error("Not implemented") }
    var isHiddenViaEmulation: Bool { error("Not implemented") }
    func setSize(_ size: CGSize) { error("Not implemented") }

    func setTopLeftCorner(_ point: CGPoint) { error("Not implemented") }
}

extension Window {
    var isFloating: Bool { parent is Workspace } // todo drop. It will be a source of bugs when sticky is introduced

    @discardableResult
    func bindAsFloatingWindow(to workspace: Workspace) -> BindingData? {
        bind(to: workspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }

    var ownIndex: Int { ownIndexOrNil! }
}

@inlinable func windowsCantHaveChildren() -> Never {
    error("Windows are leaf nodes. They can't have children")
}
