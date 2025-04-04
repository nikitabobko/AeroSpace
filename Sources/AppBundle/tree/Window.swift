import AppKit
import Common

class Window: TreeNode, Hashable {
    nonisolated let windowId: UInt32 // todo nonisolated keyword is no longer necessary?
    let app: any AbstractApp
    override var parent: NonLeafTreeNodeObject { super.parent ?? errorT("Windows always have parent") }
    var parentOrNilForTests: NonLeafTreeNodeObject? { super.parent }
    var lastFloatingSize: CGSize?
    var isFullscreen: Bool = false
    var noOuterGapsInFullscreen: Bool = false
    var layoutReason: LayoutReason = .standard

    @MainActor
    init(id: UInt32, _ app: any AbstractApp, lastFloatingSize: CGSize?, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        self.windowId = id
        self.app = app
        self.lastFloatingSize = lastFloatingSize
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor static func get(byId windowId: UInt32) -> Window? { // todo make non optional
        isUnitTest
            ? Workspace.all.flatMap { $0.allLeafWindowsRecursive }.first(where: { $0.windowId == windowId })
            : MacWindow.allWindowsMap[windowId]
    }

    @MainActor
    func closeAxWindow() { error("Not implemented") }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(windowId)
    }

    @MainActor // todo can be dropped in future Swift versions?
    func getAxTopLeftCorner() async throws -> CGPoint? { error("Not implemented") }
    @MainActor // todo swift is stupid
    func getAxSize() async throws -> CGSize? { error("Not implemented") }
    @MainActor // todo swift is stupid
    var title: String { get async throws { error("Not implemented") } }
    @MainActor // todo swift is stupid
    var isMacosFullscreen: Bool { get async throws { false } }
    @MainActor // todo swift is stupid
    var isMacosMinimized: Bool { get async throws { false } } // todo replace with enum MacOsWindowNativeState { normal, fullscreen, invisible }
    var isHiddenInCorner: Bool { error("Not implemented") }
    @MainActor
    func nativeFocus() { error("Not implemented") }
    @MainActor // todo can be dropped in future Swift versions
    func getAxRect() async throws -> Rect? { error("Not implemented") }
    @MainActor // todo can be dropped in future Swift versions
    func getCenter() async throws -> CGPoint? { try await getAxRect()?.center }

    func setAxTopLeftCorner(_ point: CGPoint) { error("Not implemented") }
    func setAxFrameDuringTermination(_ topLeft: CGPoint?, _ size: CGSize?) async throws { error("Not implemented") }
    func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) { error("Not implemented") }
    func setSizeAsync(_ size: CGSize) { error("Not implemented") }
}

enum LayoutReason: Equatable {
    case standard
    /// Reason for the cur temp layout is macOS native fullscreen, minimize, or hide
    case macos(prevParentKind: NonLeafTreeNodeKind)
}

extension Window {
    var isFloating: Bool { parent is Workspace } // todo drop. It will be a source of bugs when sticky is introduced

    @discardableResult
    @MainActor
    func bindAsFloatingWindow(to workspace: Workspace) -> BindingData? {
        bind(to: workspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }

    var ownIndex: Int { ownIndexOrNil! }

    func asMacWindow() -> MacWindow { self as! MacWindow }
}
