import AppKit
import Common

class Window: TreeNode, Hashable {
    let windowId: UInt32
    let app: AbstractApp
    override var parent: NonLeafTreeNodeObject { super.parent ?? errorT("Windows always have parent") }
    var parentOrNilForTests: NonLeafTreeNodeObject? { super.parent }
    var lastFloatingSize: CGSize?
    var isFullscreen: Bool = false
    var noOuterGapsInFullscreen: Bool = false
    var layoutReason: LayoutReason = .standard

    init(id: UInt32, _ app: AbstractApp, lastFloatingSize: CGSize?, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        self.windowId = id
        self.app = app
        self.lastFloatingSize = lastFloatingSize
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    static func get(byId windowId: UInt32) -> Window? {
        isUnitTest
            ? Workspace.all.flatMap { $0.allLeafWindowsRecursive }.first(where: { $0.windowId == windowId })
            : MacWindow.allWindowsMap[windowId]
    }

    func close() -> Bool {
        error("Not implemented")
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(windowId)
    }

    func getTopLeftCorner() -> CGPoint? { error("Not implemented") }
    func getSize() -> CGSize? { error("Not implemented") }
    var title: String { error("Not implemented") }
    var isMacosFullscreen: Bool { false }
    var isMacosMinimized: Bool { false } // todo replace with enum MacOsWindowNativeState { normal, fullscreen, invisible }
    var isHiddenInCorner: Bool { error("Not implemented") }
    func setSize(_ size: CGSize) -> Bool { error("Not implemented") }

    func setTopLeftCorner(_ point: CGPoint) -> Bool { error("Not implemented") }
}

enum LayoutReason: Equatable {
    case standard
    /// Reason for the cur temp layout is macOS native fullscreen, minimize, or hide
    case macos(prevParentKind: NonLeafTreeNodeKind)
}

extension Window {
    var isFloating: Bool { parent is Workspace } // todo drop. It will be a source of bugs when sticky is introduced

    @discardableResult
    func bindAsFloatingWindow(to workspace: Workspace) -> BindingData? {
        bind(to: workspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }

    var ownIndex: Int { ownIndexOrNil! }

    func setFrame(_ topLeft: CGPoint?, _ size: CGSize?) -> Bool {
        // Set size and then the position. The order is important https://github.com/nikitabobko/AeroSpace/issues/143
        var result: Bool = true
        if let size { result = setSize(size) && result }
        if let topLeft { result = setTopLeftCorner(topLeft) && result }
        return result
    }

    func asMacWindow() -> MacWindow { self as! MacWindow }
}
