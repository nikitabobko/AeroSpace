import AppKit
import Common

class Window: TreeNode, Hashable {
    let windowId: UInt32
    let app: AbstractApp
    override var parent: NonLeafTreeNodeObject { super.parent ?? errorT("Windows always have parent") }
    var parentOrNilForTests: NonLeafTreeNodeObject? { super.parent }
    var lastFloatingSize: CGSize?
    var isFullscreen: Bool = false
    var layoutReason: LayoutReason = .standard

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
    var title: String { error("Not implemented") }
    var isMacosFullscreen: Bool { false }
    var isMacosMinimized: Bool { false } // todo replace with enum MacOsWindowNativeState { normal, fullscreen, invisible }
    var isHiddenViaEmulation: Bool { error("Not implemented") }
    func setSize(_ size: CGSize) -> Bool { error("Not implemented") }

    func setTopLeftCorner(_ point: CGPoint) -> Bool { error("Not implemented") }
}

enum LayoutReason: Equatable {
    case standard
    /// Reason for the cur temp layout is macOS native fullscreen, minimize, or hide
    case macos(prevParentKind: NonLeafTreeNodeKind)

    var isMacos: Bool {
        if case .macos = self {
            return true
        } else {
            return false
        }
    }
}

extension Window {
    var isFloating: Bool { parent is Workspace } // todo drop. It will be a source of bugs when sticky is introduced

    @discardableResult
    func bindAsFloatingWindow(to workspace: Workspace) -> BindingData? {
        bind(to: workspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }

    var ownIndex: Int { ownIndexOrNil! }

    func focus() -> Bool { // todo rename: focusWindowAndWorkspace
        markAsMostRecentChild()
        // todo bug make the workspace active first...
        if let workspace = workspace ?? nodeMonitor?.activeWorkspace { // todo change focusedWorkspaceName to focused monitor
            focusedWorkspaceName = workspace.name
            return nodeMonitor?.setActiveWorkspace(workspace) ?? true
        } // else if We should exit-native-fullscreen/unminimize window if we want to fix ID-B6E178F2
        return true
    }

    func setFrame(_ topLeft: CGPoint?, _ size: CGSize?) -> Bool {
        // Set size and then the position. The order is important https://github.com/nikitabobko/AeroSpace/issues/143
        var result: Bool = true
        if let size { result = setSize(size) && result }
        if let topLeft { result = setTopLeftCorner(topLeft) && result }
        return result
    }

    func asMacWindow() -> MacWindow { self as! MacWindow }
}

@inlinable func windowsCantHaveChildren() -> Never {
    error("Windows are leaf nodes. They can't have children")
}
