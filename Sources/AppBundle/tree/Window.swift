import AppKit
import Common

open class Window: TreeNode, Hashable {
    let windowId: OpaqueWindowId
    let app: any AbstractApp
    var lastFloatingSize: CGSize?
    var isFullscreen: Bool = false
    var noOuterGapsInFullscreen: Bool = false
    var pendingFullscreenTransition: Bool = false
    var layoutReason: LayoutReason = .standard
    var lifeStatus: WindowLifeStatus = .alive

    @MainActor
    init(id: OpaqueWindowId, _ app: any AbstractApp, lastFloatingSize: CGSize?, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        self.windowId = id
        self.app = app
        self.lastFloatingSize = lastFloatingSize
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor static func get(byId windowId: OpaqueWindowId) -> Window? { // todo make non optional
        isUnitTest
            ? Workspace.all.flatMap { $0.allLeafWindowsRecursive }.first(where: { $0.windowId == windowId })
            : MacWindow.allWindowsMap[windowId]
    }

    @MainActor static func get(byNativeId nativeWindowId: UInt32, pid: pid_t) -> Window? {
        MacApp.allAppsMap[pid]?.opaqueWindowId(of: nativeWindowId).flatMap { get(byId: $0) }
    }

    @MainActor
    func closeAxWindow() { die("Not implemented") }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(windowId)
    }

    func getAxSize(_ cm: CancellationMode) async throws -> CGSize? { die("Not implemented") }
    func getTitle(_ cm: CancellationMode) async throws -> String { die("Not implemented") }

    func isMacosFullscreen(_ cm: CancellationMode) async throws -> Bool { false }
    func isMacosMinimized(_ cm: CancellationMode) async throws -> Bool { false }
    func getMacosWindowNativeState(_ cm: CancellationMode) async throws -> MacosWindowNativeState {
        if try await isMacosFullscreen(cm) { return .nativeFullscreen }
        if try await isMacosMinimized(cm) { return .nativeMinimized }
        return .normal
    }

    var isHiddenInCorner: Bool { die("Not implemented") }
    @MainActor func nativeFocus() { die("Not implemented") }
    func getAxRect(_ cm: CancellationMode) async throws -> Rect? { die("Not implemented") }
    func getCenter(_ cm: CancellationMode) async throws -> CGPoint? { try await getAxRect(cm)?.center }

    @MainActor func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?, duration: Int = 0, slideIn: WorkspaceSlide? = nil) { die("Not implemented") }
    @MainActor var isFrameAnimationInProgress: Bool { false }
    @MainActor func cancelFrameAnimation() {}
}

enum MacosWindowNativeState: Sendable {
    case normal
    case nativeMinimized
    case nativeFullscreen
}

enum LayoutReason: Equatable {
    case standard
    /// Reason for the cur temp layout is macOS native fullscreen, minimize, or hide
    case macos(prevParentKind: WindowParentCases.Kind)
}

extension Window {
    var isFloating: Bool { // todo drop. It will be a source of bugs when sticky is introduced
        switch windowParentCases {
            case .floatingWindowsContainer: true
            case .macosFullscreenWindowsContainer: false
            case .macosHiddenAppsWindowsContainer: false
            case .macosMinimizedWindowsContainer: false
            case .macosPopupWindowsContainer: false
            case .tilingContainer: false
            case nil: false
        }
    }

    @discardableResult
    @MainActor
    func bindAsFloatingWindow(to workspace: Workspace) -> BindingData? {
        bind(to: workspace.floatingWindowsContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }

    func asMacWindow() -> MacWindow { self as! MacWindow }

    @MainActor
    func consumePendingFullscreenTransition() -> Bool {
        let result = pendingFullscreenTransition
        pendingFullscreenTransition = false
        return result
    }
}
