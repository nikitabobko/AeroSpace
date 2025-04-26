import AppKit
import Common

class Window: TreeNode, Hashable {
    nonisolated let windowId: UInt32 // todo nonisolated keyword is no longer necessary?
    let app: any AbstractApp
    override var parent: NonLeafTreeNodeObject {
        super.parent ?? dieT("Windows must always have a parent. The Window was unbound at:\n\(unboundStacktrace ?? "nil")")
    }
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
    func closeAxWindow() { die("Not implemented") }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(windowId)
    }

    @MainActor // todo can be dropped in future Swift versions?
    func getAxTopLeftCorner() async throws -> CGPoint? { die("Not implemented") }
    @MainActor // todo swift is stupid
    func getAxSize() async throws -> CGSize? { die("Not implemented") }
    @MainActor // todo swift is stupid
    var title: String { get async throws { die("Not implemented") } }
    @MainActor // todo swift is stupid
    var isMacosFullscreen: Bool { get async throws { false } }
    @MainActor // todo swift is stupid
    var isMacosMinimized: Bool { get async throws { false } } // todo replace with enum MacOsWindowNativeState { normal, fullscreen, invisible }
    var isHiddenInCorner: Bool { die("Not implemented") }
    @MainActor
    func nativeFocus() { die("Not implemented") }
    @MainActor // todo can be dropped in future Swift versions
    func getAxRect() async throws -> Rect? { die("Not implemented") }
    @MainActor // todo can be dropped in future Swift versions
    func getCenter() async throws -> CGPoint? { try await getAxRect()?.center }

    func setAxTopLeftCorner(_ point: CGPoint) { die("Not implemented") }
    func setAxFrameBlocking(_ topLeft: CGPoint?, _ size: CGSize?) async throws { die("Not implemented") }
    func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) { die("Not implemented") }
    func setSizeAsync(_ size: CGSize) { die("Not implemented") }
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
