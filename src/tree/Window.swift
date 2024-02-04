import Common

class Window: TreeNode, Hashable {
    let windowId: UInt32
    let app: AbstractApp
    override var parent: NonLeafTreeNodeObject { super.parent ?? errorT("Windows always have parent") }
    var parentOrNilForTests: NonLeafTreeNodeObject? { super.parent }
    var lastFloatingSize: CGSize?
    var isFullscreen: Bool = false

    init(id: UInt32, _ app: AbstractApp, lastFloatingSize: CGSize?, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        self.windowId = id
        self.app = app
        self.lastFloatingSize = lastFloatingSize
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

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

    func focus() { // todo rename: focusWindowAndWorkspace
        markAsMostRecentChild()
        // todo bug make the workspace active first...
        focusedWorkspaceName = workspace.name
    }

    func setFrame(_ topLeft: CGPoint?, _ size: CGSize?) {
        // Set size and then the position. The order is important https://github.com/nikitabobko/AeroSpace/issues/143
        if let size { setSize(size) }
        if let topLeft { setTopLeftCorner(topLeft) }
    }

    func asMacWindow() -> MacWindow { self as! MacWindow }
}

@inlinable func windowsCantHaveChildren() -> Never {
    error("Windows are leaf nodes. They can't have children")
}
