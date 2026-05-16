import AppKit
import Common

open class Window: TreeNode, Hashable {
    let windowId: UInt32
    let app: any AbstractApp
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

    public func hash(into hasher: inout Hasher) {
        hasher.combine(windowId)
    }

    func getAxSize() async throws -> CGSize? { die("Not implemented") }
    var title: String { get async throws { die("Not implemented") } }
    var isMacosFullscreen: Bool { get async throws { false } }
    var isMacosMinimized: Bool { get async throws { false } } // todo replace with enum MacOsWindowNativeState { normal, fullscreen, invisible }
    var isHiddenInCorner: Bool { die("Not implemented") }
    @MainActor
    func nativeFocus() { die("Not implemented") }
    func getAxRect() async throws -> Rect? { die("Not implemented") }
    func getCenter() async throws -> CGPoint? { try await getAxRect()?.center }

    func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) { die("Not implemented") }
}

enum LayoutReason {
    case standard
    /// Reason for the cur temp layout is macOS native fullscreen, minimize, or hide.
    /// Carries the previous binding so the window can be restored to the exact
    /// nested container + index it came from, instead of being dumped at the end
    /// of the workspace's root tiling container.
    case macos(prev: MacosPrev)
}

@MainActor
final class MacosPrev {
    /// Weak so workspace teardown can still gc the container if it's legitimately
    /// destroyed. While we hold a pending count on `parent` (see below), the
    /// container's normal parent-children strong refs keep it alive -- so this
    /// weak ref stays valid for the lifetime of the unconventional state.
    weak var parent: NonLeafTreeNodeObject?
    let parentKind: NonLeafTreeNodeKind
    let index: Int
    let adaptiveWeight: CGFloat
    /// Sibling anchors captured at fullscreen entry. On exit we look these up in
    /// the parent's current children to find the correct insertion point even if
    /// the parent's child list has shifted in the meantime (e.g., another window
    /// briefly gc'd and re-registered during the fullscreen transition).
    let nextSiblingWindowId: UInt32?
    let prevSiblingWindowId: UInt32?

    init(parent: NonLeafTreeNodeObject, index: Int, adaptiveWeight: CGFloat) {
        self.parent = parent
        self.parentKind = parent.kind
        self.index = index
        self.adaptiveWeight = adaptiveWeight
        // index here is the window's own index in parent.children BEFORE it has
        // moved into the unconventional container.
        let nextIdx = index + 1
        let prevIdx = index - 1
        self.nextSiblingWindowId = nextIdx < parent.children.count
            ? (parent.children[nextIdx] as? Window)?.windowId
            : nil
        self.prevSiblingWindowId = prevIdx >= 0
            ? (parent.children[prevIdx] as? Window)?.windowId
            : nil
        // Mark the container as having a logical child currently away in
        // unconventional state, so `unbindEmptyAndAutoFlatten` won't flatten it
        // out from under us.
        (parent as? TilingContainer)?.pendingFullscreenChildren += 1
    }

    isolated deinit {
        // Symmetric release. Runs when the owning window's layoutReason transitions
        // away from .macos, OR when the window itself is deallocated while still
        // in unconventional state (e.g. gc'd during fullscreen). `parent` is weak
        // and may already be nil if the container was destroyed externally -- in
        // that case there's no counter to decrement anyway.
        (parent as? TilingContainer)?.pendingFullscreenChildren -= 1
    }

    @MainActor
    func resolveIndex(in parent: NonLeafTreeNodeObject) -> Int {
        if let nextId = nextSiblingWindowId,
           let nextIdx = parent.children.firstIndex(where: { ($0 as? Window)?.windowId == nextId })
        {
            return nextIdx
        }
        if nextSiblingWindowId == nil {
            return parent.children.count
        }
        if let prevId = prevSiblingWindowId,
           let prevIdx = parent.children.firstIndex(where: { ($0 as? Window)?.windowId == prevId })
        {
            return prevIdx + 1
        }
        return min(index, parent.children.count)
    }
}

extension Window {
    var isFloating: Bool { parent is Workspace } // todo drop. It will be a source of bugs when sticky is introduced

    @discardableResult
    @MainActor
    func bindAsFloatingWindow(to workspace: Workspace) -> BindingData? {
        bind(to: workspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }

    func asMacWindow() -> MacWindow { self as! MacWindow }
}
