import AppKit
import Common

@MainActor
final class RecentBinding {
    weak var parent: NonLeafTreeNodeObject?
    /// `index` is captured at gc time, but the parent's children can shift between
    /// gc and re-registration (e.g., another sibling enters native fullscreen).
    /// `prevSiblingWindowId` is a stable anchor: the id of the sibling that was
    /// immediately before this window. We look it up at restore time and place
    /// this window right after it, falling back to the saved index if the anchor
    /// is gone.
    let index: Int
    let prevSiblingWindowId: UInt32?
    let adaptiveWeight: CGFloat
    init(_ binding: BindingData) {
        self.parent = binding.parent
        self.index = binding.index
        let priorIdx = binding.index - 1
        self.prevSiblingWindowId = priorIdx >= 0 && priorIdx < binding.parent.children.count
            ? (binding.parent.children[priorIdx] as? Window)?.windowId
            : nil
        self.adaptiveWeight = binding.adaptiveWeight
    }

    @MainActor
    func resolveIndex(in parent: NonLeafTreeNodeObject) -> Int {
        if let prevId = prevSiblingWindowId,
           let anchor = parent.children.firstIndex(where: { ($0 as? Window)?.windowId == prevId })
        {
            return anchor + 1
        }
        return min(index, parent.children.count)
    }
}

final class MacWindow: Window {
    let macApp: MacApp
    private var prevUnhiddenProportionalPositionInsideWorkspaceRect: CGPoint?

    @MainActor
    private init(_ id: UInt32, _ actor: MacApp, lastFloatingSize: CGSize?, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        self.macApp = actor
        super.init(id: id, actor, lastFloatingSize: lastFloatingSize, parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor static var allWindowsMap: [UInt32: MacWindow] = [:]
    @MainActor static var allWindows: [MacWindow] { Array(allWindowsMap.values) }

    /// Window ids that were garbage-collected very recently. Some AX state changes
    /// (e.g., another app entering native fullscreen) momentarily make a window's
    /// `containingWindowId()` return nil, so the refresh loop gc's it and then
    /// re-registers it on the next refresh. Without this set, `getOrRegister`
    /// would treat the re-registration as a brand-new window and trigger
    /// `pair-new-window-with-focused`, wrapping the re-registered window in an
    /// h_accordion container with whatever is MRU -- visually hiding the window.
    @MainActor static var recentlyGcdAt: [UInt32: Date] = [:]
    @MainActor static var recentlyGcdBindings: [UInt32: RecentBinding] = [:]
    /// Longer than typical AX transient (~few seconds) but short enough that the
    /// bookkeeping doesn't grow unbounded. Window position recovery only matters
    /// while the window is briefly dead during a fullscreen transition.
    private static let recentlyGcdWindow: TimeInterval = 60.0

    /// Any window id this AeroSpace instance has ever registered. A windowId
    /// that's been seen before is by definition not a "new window" -- it's the
    /// same window returning from a transient AX state. Without this,
    /// pair-new-window-with-focused triggers for windows that briefly vanish
    /// during another app's native fullscreen and wraps them in an h_accordion
    /// container, visually hiding them behind whatever was MRU.
    @MainActor private static var everSeenWindowIds: Set<UInt32> = []
    @MainActor static func wasEverSeen(_ windowId: UInt32) -> Bool { everSeenWindowIds.contains(windowId) }
    @MainActor static func markSeen(_ windowId: UInt32) { everSeenWindowIds.insert(windowId) }

    /// AeroSpace fires multiple refresh sessions back-to-back when it launches:
    /// some have `isStartup=true`, some don't (AX-event-triggered refreshes that
    /// ran outside the startup TaskLocal scope). Treat anything within this
    /// grace window as pre-existing.
    @MainActor static let aerospaceStartedAt: Date = .now
    private static let startupGraceWindow: TimeInterval = 5.0
    @MainActor static var isWithinStartupGrace: Bool {
        aerospaceStartedAt.distance(to: .now) < startupGraceWindow
    }

    @MainActor static func wasRecentlyGcd(_ windowId: UInt32) -> Bool {
        guard let when = recentlyGcdAt[windowId] else { return false }
        if when.distance(to: .now) > recentlyGcdWindow {
            recentlyGcdAt.removeValue(forKey: windowId)
            recentlyGcdBindings.removeValue(forKey: windowId)
            return false
        }
        return true
    }

    @MainActor static func popRecentlyGcdBinding(_ windowId: UInt32) -> RecentBinding? {
        guard wasRecentlyGcd(windowId) else { return nil }
        defer {
            recentlyGcdAt.removeValue(forKey: windowId)
            recentlyGcdBindings.removeValue(forKey: windowId)
        }
        return recentlyGcdBindings[windowId]
    }

    @MainActor static func recordGcdBinding(_ windowId: UInt32, _ binding: BindingData) {
        recentlyGcdAt[windowId] = .now
        recentlyGcdBindings[windowId] = RecentBinding(binding)
    }

    /// Synchronous swap-registration used during a tab swap in tab-based apps.
    /// Doing this without awaits ensures the workspace tree is never observed in a
    /// "gap" state (between the stale tab being unbound and the new tab being bound),
    /// which is critical because the refresh task can be cancelled mid-await and
    /// leave the tree without a tile until the next refresh -- a visible flicker.
    @MainActor
    static func registerWithInheritedBinding(windowId: UInt32, macApp: MacApp, binding: BindingData) -> MacWindow {
        if let existing = allWindowsMap[windowId] { return existing }
        let window = MacWindow(windowId, macApp, lastFloatingSize: nil, parent: binding.parent, adaptiveWeight: binding.adaptiveWeight, index: binding.index)
        allWindowsMap[windowId] = window
        return window
    }

    @MainActor
    @discardableResult
    static func getOrRegister(windowId: UInt32, macApp: MacApp) async throws -> MacWindow {
        if let existing = allWindowsMap[windowId] { return existing }
        let rect = try await macApp.getAxRect(windowId)

        // If this id was gc'd very recently, it's the same window briefly bouncing
        // through an AX transient state (e.g., another app entering native
        // fullscreen). Restore it to the exact slot it occupied before, instead
        // of re-classifying it as a new window and placing it next to the MRU.
        if let saved = popRecentlyGcdBinding(windowId),
           let savedParent = saved.parent,
           savedParent.nodeWorkspace != nil
        {
            let window = MacWindow(windowId, macApp, lastFloatingSize: rect?.size, parent: savedParent, adaptiveWeight: WEIGHT_AUTO, index: saved.resolveIndex(in: savedParent))
            allWindowsMap[windowId] = window
            markSeen(windowId)
            return window
        }

        // Falling back to classification means we don't have a saved binding to
        // restore from. The window is genuinely new only if all of these are true:
        //  - AeroSpace is not in startup discovery (TaskLocal or grace window).
        //  - AeroSpace has never registered this windowId before.
        // Otherwise it's the same window returning from a transient AX state
        // (e.g., re-classified during another app's native fullscreen
        // transition) and we must not run pair-new-window-with-focused on it.
        let isGenuinelyNew = !isStartup
            && !MacWindow.isWithinStartupGrace
            && !MacWindow.wasEverSeen(windowId)
        MacWindow.markSeen(windowId)
        let data = try await unbindAndGetBindingDataForNewWindow(
            windowId,
            macApp,
            isStartup
                ? (rect?.center.monitorApproximation ?? mainMonitor).activeWorkspace
                : focus.workspace,
            window: nil,
            isNewWindow: isGenuinelyNew,
        )

        // atomic synchronous section
        if let existing = allWindowsMap[windowId] { return existing }
        let window = MacWindow(windowId, macApp, lastFloatingSize: rect?.size, parent: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
        allWindowsMap[windowId] = window

        try await debugWindowsIfRecording(window)
        if try await !restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: window) {
            try await tryOnWindowDetected(window)
        }
        return window
    }

    // var description: String {
    //     let description = [
    //         ("title", title),
    //         ("role", axWindow.get(Ax.roleAttr)),
    //         ("subrole", axWindow.get(Ax.subroleAttr)),
    //         ("identifier", axWindow.get(Ax.identifierAttr)),
    //         ("modal", axWindow.get(Ax.modalAttr).map { String($0) } ?? ""),
    //         ("windowId", String(windowId)),
    //     ].map { "\($0.0): '\(String(describing: $0.1))'" }.joined(separator: ", ")
    //     return "Window(\(description))"
    // }

    func isWindowHeuristic(_ windowLevel: MacOsWindowLevel?) async throws -> Bool { // todo cache
        try await macApp.isWindowHeuristic(windowId, windowLevel)
    }

    func isDialogHeuristic(_ windowLevel: MacOsWindowLevel?) async throws -> Bool { // todo cache
        try await macApp.isDialogHeuristic(windowId, windowLevel)
    }

    func dumpAxInfo() async throws -> [String: Json] {
        try await macApp.dumpWindowAxInfo(windowId: windowId)
    }

    func setNativeFullscreen(_ value: Bool) {
        macApp.setNativeFullscreen(windowId, value)
    }

    func setNativeMinimized(_ value: Bool) {
        macApp.setNativeMinimized(windowId, value)
    }

    // skipClosedWindowsCache is an optimization when it's definitely not necessary to cache closed window.
    //                        If you are unsure, it's better to pass `false`
    @MainActor
    func garbageCollect(skipClosedWindowsCache: Bool) {
        if MacWindow.allWindowsMap.removeValue(forKey: windowId) == nil {
            return
        }
        if !skipClosedWindowsCache { cacheClosedWindowIfNeeded() }
        let binding = unbindFromParent()
        let parent = binding.parent
        // Remember the exact slot so a near-immediate re-registration (transient
        // AX state, not the user opening a new window) can be placed back in
        // the same spot rather than being re-classified as a new window.
        if !skipClosedWindowsCache { MacWindow.recordGcdBinding(windowId, binding) }
        let deadWindowWorkspace = parent.nodeWorkspace
        let focus = focus
        if let deadWindowWorkspace, deadWindowWorkspace == focus.workspace ||
            deadWindowWorkspace == prevFocusedWorkspace && prevFocusedWorkspaceDate.distance(to: .now) < 1
        {
            switch parent.cases {
                case .tilingContainer, .workspace, .macosHiddenAppsWindowsContainer, .macosFullscreenWindowsContainer:
                    let deadWindowFocus = deadWindowWorkspace.toLiveFocus()
                    _ = setFocus(to: deadWindowFocus)
                    // Guard against "Apple Reminders popup" bug: https://github.com/nikitabobko/AeroSpace/issues/201
                    if focus.windowOrNil?.app.pid != app.pid {
                        // Force focus to fix macOS annoyance with focused apps without windows.
                        //   https://github.com/nikitabobko/AeroSpace/issues/65
                        deadWindowFocus.windowOrNil?.nativeFocus()
                    }
                case .macosPopupWindowsContainer, .macosMinimizedWindowsContainer:
                    break // Don't switch back on popup destruction
            }
        }
    }

    @MainActor override var title: String { get async throws { try await macApp.getAxTitle(windowId) ?? "" } }
    @MainActor override var isMacosFullscreen: Bool { get async throws { try await macApp.isMacosNativeFullscreen(windowId) == true } }
    @MainActor override var isMacosMinimized: Bool { get async throws { try await macApp.isMacosNativeMinimized(windowId) == true } }

    @MainActor
    override func nativeFocus() {
        macApp.nativeFocus(windowId)
    }

    override func closeAxWindow() {
        garbageCollect(skipClosedWindowsCache: true)
        macApp.closeAndUnregisterAxWindow(windowId)
    }

    // todo it's part of the window layout and should be moved to layoutRecursive.swift
    @MainActor
    func hideInCorner(_ corner: OptimalHideCorner) async throws {
        guard let nodeMonitor else { return }
        // Don't accidentally override prevUnhiddenEmulationPosition in case of subsequent `hideInCorner` calls
        if !isHiddenInCorner {
            guard let windowRect = try await getAxRect() else { return }
            // Check for isHiddenInCorner for the second time because of the suspension point above
            if !isHiddenInCorner {
                let topLeftCorner = windowRect.topLeftCorner
                let monitorRect = windowRect.center.monitorApproximation.rect // Similar to layoutFloatingWindow. Non idempotent
                let absolutePoint = topLeftCorner - monitorRect.topLeftCorner
                prevUnhiddenProportionalPositionInsideWorkspaceRect =
                    CGPoint(x: absolutePoint.x / monitorRect.width, y: absolutePoint.y / monitorRect.height)
            }
        }
        let p: CGPoint
        switch corner {
            case .bottomLeftCorner:
                guard let s = try await getAxSize() else { fallthrough }
                // Zoom will jump off if you do one pixel offset https://github.com/nikitabobko/AeroSpace/issues/527
                // todo this ad hoc won't be necessary once I implement optimization suggested by Zalim
                let onePixelOffset = macApp.appId == .zoom ? .zero : CGPoint(x: 1, y: -1)
                p = nodeMonitor.visibleRect.bottomLeftCorner + onePixelOffset + CGPoint(x: -s.width, y: 0)
            case .bottomRightCorner:
                // Zoom will jump off if you do one pixel offset https://github.com/nikitabobko/AeroSpace/issues/527
                // todo this ad hoc won't be necessary once I implement optimization suggested by Zalim
                let onePixelOffset = macApp.appId == .zoom ? .zero : CGPoint(x: 1, y: 1)
                p = nodeMonitor.visibleRect.bottomRightCorner - onePixelOffset
        }
        setAxFrame(p, nil)
    }

    @MainActor
    func unhideFromCorner() {
        guard let prevUnhiddenProportionalPositionInsideWorkspaceRect else { return }
        guard let nodeWorkspace else { return } // hiding only makes sense for workspace windows
        guard let parent else { return }

        switch getChildParentRelation(child: self, parent: parent) {
            // Just a small optimization to avoid unnecessary AX calls for non floating windows
            // Tiling windows should be unhidden with layoutRecursive anyway
            case .floatingWindow:
                let workspaceRect = nodeWorkspace.workspaceMonitor.rect
                var newX = workspaceRect.topLeftX + workspaceRect.width * prevUnhiddenProportionalPositionInsideWorkspaceRect.x
                var newY = workspaceRect.topLeftY + workspaceRect.height * prevUnhiddenProportionalPositionInsideWorkspaceRect.y
                // todo we probably should replace lastFloatingSize with proper floating window sizing
                // https://github.com/nikitabobko/AeroSpace/issues/1519
                let windowWidth = lastFloatingSize?.width ?? 0
                let windowHeight = lastFloatingSize?.height ?? 0
                newX = newX.coerce(in: workspaceRect.minX ... max(workspaceRect.minX, workspaceRect.maxX - windowWidth))
                newY = newY.coerce(in: workspaceRect.minY ... max(workspaceRect.minY, workspaceRect.maxY - windowHeight))

                setAxFrame(CGPoint(x: newX, y: newY), nil)
            case .macosNativeFullscreenWindow, .macosNativeHiddenAppWindow, .macosNativeMinimizedWindow,
                 .macosPopupWindow, .tiling, .rootTilingContainer, .shimContainerRelation: break
        }

        self.prevUnhiddenProportionalPositionInsideWorkspaceRect = nil
    }

    override var isHiddenInCorner: Bool {
        prevUnhiddenProportionalPositionInsideWorkspaceRect != nil
    }

    override func getAxSize() async throws -> CGSize? {
        try await macApp.getAxSize(windowId)
    }

    override func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) {
        macApp.setAxFrame(windowId, topLeft, size)
    }

    func setAxFrameBlocking(_ topLeft: CGPoint?, _ size: CGSize?) async throws {
        try await macApp.setAxFrameBlocking(windowId, topLeft, size)
    }

    override func getAxRect() async throws -> Rect? {
        try await macApp.getAxRect(windowId)
    }
}

extension Window {
    @MainActor
    func relayoutWindow(on workspace: Workspace, forceTile: Bool = false) async throws {
        let data = forceTile
            ? unbindAndGetBindingDataForNewTilingWindow(workspace, window: self, isNewWindow: false)
            : try await unbindAndGetBindingDataForNewWindow(self.asMacWindow().windowId, self.asMacWindow().macApp, workspace, window: self, isNewWindow: false)
        bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
    }
}

// The function is private because it's unsafe. It leaves the window in unbound state
@MainActor
private func unbindAndGetBindingDataForNewWindow(_ windowId: UInt32, _ macApp: MacApp, _ workspace: Workspace, window: Window?, isNewWindow: Bool) async throws -> BindingData {
    let windowLevel = getWindowLevel(for: windowId)
    return switch try await macApp.getAxUiElementWindowType(windowId, windowLevel) {
        case .popup: BindingData(parent: macosPopupWindowsContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        case .dialog: BindingData(parent: workspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        case .window: unbindAndGetBindingDataForNewTilingWindow(workspace, window: window, isNewWindow: isNewWindow)
    }
}

// The function is private because it's unsafe. It leaves the window in unbound state
@MainActor
private func unbindAndGetBindingDataForNewTilingWindow(_ workspace: Workspace, window: Window?, isNewWindow: Bool) -> BindingData {
    window?.unbindFromParent() // It's important to unbind to get correct data from below
    let mruWindow = workspace.mostRecentWindowRecursive

    // Wrap the new window together with the MRU (previously focused) window in a fresh
    // container of the configured layout. The new container takes the MRU's slot in its
    // original parent, and the MRU + new window become its only children.
    if isNewWindow,
       case let .wrap(orientation, layout) = config.pairNewWindowWithFocused,
       let mruWindow,
       let mruParent = mruWindow.parent as? TilingContainer
    {
        let mruBinding = mruWindow.unbindFromParent()
        let newContainer = TilingContainer(
            parent: mruParent,
            adaptiveWeight: mruBinding.adaptiveWeight,
            orientation,
            layout,
            index: mruBinding.index,
        )
        mruWindow.bind(to: newContainer, adaptiveWeight: WEIGHT_AUTO, index: 0)
        return BindingData(parent: newContainer, adaptiveWeight: WEIGHT_AUTO, index: 1)
    }

    if let mruWindow, let tilingParent = mruWindow.parent as? TilingContainer {
        return BindingData(
            parent: tilingParent,
            adaptiveWeight: WEIGHT_AUTO,
            index: mruWindow.ownIndex.orDie() + 1,
        )
    } else {
        return BindingData(
            parent: workspace.rootTilingContainer,
            adaptiveWeight: WEIGHT_AUTO,
            index: INDEX_BIND_LAST,
        )
    }
}

@MainActor
func tryOnWindowDetected(_ window: Window) async throws {
    guard let parent = window.parent else { return }
    switch parent.cases {
        case .tilingContainer, .workspace, .macosMinimizedWindowsContainer,
             .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
            try await onWindowDetected(window)
        case .macosPopupWindowsContainer:
            break
    }
}

@MainActor
private func onWindowDetected(_ window: Window) async throws {
    broadcastEvent(.windowDetected(
        windowId: window.windowId,
        workspace: window.nodeWorkspace?.name,
        appBundleId: window.app.rawAppBundleId,
        appName: window.app.name,
    ))
    for callback in config.onWindowDetected where try await callback.matches(window) {
        _ = try await callback.run.runCmdSeq(.defaultEnv.copy(\.windowId, window.windowId), .emptyStdin)
        if !callback.checkFurtherCallbacks {
            return
        }
    }
}

extension WindowDetectedCallback {
    @MainActor
    func matches(_ window: Window) async throws -> Bool {
        if let startupMatcher = matcher.duringAeroSpaceStartup, startupMatcher != isStartup {
            return false
        }
        if let regex = matcher.windowTitleRegexSubstring, !(try await window.title).contains(caseInsensitiveRegex: regex) {
            return false
        }
        if let appId = matcher.appId, appId != window.app.rawAppBundleId {
            return false
        }
        if let regex = matcher.appNameRegexSubstring, !(window.app.name ?? "").contains(caseInsensitiveRegex: regex) {
            return false
        }
        if let workspace = matcher.workspace, workspace != window.nodeWorkspace?.name {
            return false
        }
        return true
    }
}
