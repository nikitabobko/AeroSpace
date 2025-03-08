import AppKit
import Common

final class MacWindow: Window {
    let macApp: MacApp
    // todo take into account monitor proportions
    private var prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect: CGPoint?
    private var axObservers: [AxObserverWrapper] = [] // keep observers in memory

    @MainActor
    private init(_ id: UInt32, _ actor: MacApp, lastFloatingSize: CGSize?, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        self.macApp = actor
        super.init(id: id, actor, lastFloatingSize: lastFloatingSize, parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor static var allWindowsMap: [UInt32: MacWindow] = [:]
    @MainActor static var allWindows: [MacWindow] { Array(allWindowsMap.values) }

    @MainActor
    static func getOrRegister(windowId: UInt32, macApp: MacApp) async throws -> MacWindow {
        if let existing = allWindowsMap[windowId] { return existing }
        let rect = try await macApp.getRect(windowId)
        let data = try await getBindingDataForNewWindow(
            windowId,
            macApp,
            isStartup
                ? (rect?.center.monitorApproximation ?? mainMonitor).activeWorkspace
                : focus.workspace
        )

        let window = { // atomic synchronous section
            if let existing = allWindowsMap[windowId] { return existing }
            let window = MacWindow(windowId, macApp, lastFloatingSize: rect?.size, parent: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
            allWindowsMap[windowId] = window
            return window
        }()

        try await debugWindowsIfRecording(window)
        if try await !restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: window) {
            try await tryOnWindowDetected(window, startup: isStartup)
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

    @MainActor // todo swift is stupid
    func isWindow() async throws -> Bool {
        try await macApp.isWindow(windowId)
    }

    @MainActor // todo swift is stupid
    func dumpAx(_ prefix: String) async throws -> String {
        try await macApp.dumpWindowAx(windowId: windowId, prefix)
    }

    func setNativeFullscreenAsync(_ value: Bool) {
        macApp.setNativeFullscreenAsync(windowId, value)
    }

    func setNativeMinimizedAsync(_ value: Bool) {
        macApp.setNativeMinimizedAsync(windowId, value)
    }

    // skipClosedWindowsCache is an optimization when it's definitely not necessary to cache closed window.
    //                        If you are unsure, it's better to pass `false`
    @MainActor
    func garbageCollect(skipClosedWindowsCache: Bool) {
        if MacWindow.allWindowsMap.removeValue(forKey: windowId) == nil {
            return
        }
        if !skipClosedWindowsCache { cacheClosedWindowIfNeeded(window: self) }
        let parent = unbindFromParent().parent
        let deadWindowWorkspace = parent.nodeWorkspace
        for obs in axObservers {
            AXObserverRemoveNotification(obs.obs, obs.ax, obs.notif)
        }
        axObservers = []
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
                        deadWindowFocus.windowOrNil?.nativeFocusAsync()
                    }
                case .macosPopupWindowsContainer, .macosMinimizedWindowsContainer:
                    break // Don't switch back on popup destruction
            }
        }
    }

    @MainActor override var title: String { get async throws { try await macApp.getTitle(windowId) ?? "" } }
    @MainActor override var isMacosFullscreen: Bool { get async throws { try await macApp.isMacosNativeFullscreen(windowId) == true } }
    @MainActor override var isMacosMinimized: Bool { get async throws { try await macApp.isMacosNativeMinimized(windowId) == true } }

    @MainActor
    override func nativeFocusAsync() {
        macApp.nativeFocusAsync(windowId)
    }

    override func close() {
        macApp.closeWindowInBg(windowId)
        garbageCollect(skipClosedWindowsCache: true)
    }

    @MainActor
    func hideInCorner(_ corner: OptimalHideCorner) async throws {
        guard let nodeMonitor else { return }
        // Don't accidentally override prevUnhiddenEmulationPosition in case of subsequent
        // `hideEmulation` calls
        if !isHiddenInCorner {
            guard let topLeftCorner = try await getTopLeftCorner() else { return }
            guard let nodeWorkspace else { return } // hiding only makes sense for workspace windows
            prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect =
                topLeftCorner - nodeWorkspace.workspaceMonitor.rect.topLeftCorner
        }
        let p: CGPoint
        switch corner {
            case .bottomLeftCorner:
                guard let s = try await getSize() else { fallthrough }
                // Zoom will jump off if you do one pixel offset https://github.com/nikitabobko/AeroSpace/issues/527
                // todo this ad hoc won't be necessary once I implement optimization suggested by Zalim
                let onePixelOffset = macApp.isZoom ? .zero : CGPoint(x: 1, y: -1)
                p = nodeMonitor.visibleRect.bottomLeftCorner + onePixelOffset + CGPoint(x: -s.width, y: 0)
            case .bottomRightCorner:
                // Zoom will jump off if you do one pixel offset https://github.com/nikitabobko/AeroSpace/issues/527
                // todo this ad hoc won't be necessary once I implement optimization suggested by Zalim
                let onePixelOffset = macApp.isZoom ? .zero : CGPoint(x: 1, y: 1)
                p = nodeMonitor.visibleRect.bottomRightCorner - onePixelOffset
        }
        setTopLeftCornerAsync(p)
    }

    @MainActor
    func unhideFromCorner() {
        guard let prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect else { return }
        guard let nodeWorkspace else { return } // hiding only makes sense for workspace windows

        switch getChildParentRelation(child: self, parent: parent) {
            // Just a small optimization to avoid unnecessary AX calls for non floating windows
            // Tiling windows should be unhidden with layoutRecursive anyway
            case .floatingWindow:
                setTopLeftCornerAsync(nodeWorkspace.workspaceMonitor.rect.topLeftCorner + prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect)
            case .macosNativeFullscreenWindow, .macosNativeHiddenAppWindow, .macosNativeMinimizedWindow,
                 .macosPopupWindow, .tiling, .rootTilingContainer, .shimContainerRelation: break
        }

        self.prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect = nil
    }

    override var isHiddenInCorner: Bool {
        prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect != nil
    }

    @MainActor // todo swift is stupid
    override func getSize() async throws -> CGSize? {
        try await macApp.getSize(windowId)
    }

    override func setTopLeftCornerAsync(_ point: CGPoint) {
        macApp.setTopLeftCornerAsync(windowId, point)
    }

    override func setFrameAsync(_ topLeft: CGPoint?, _ size: CGSize?) {
        macApp.setFrameAsync(windowId, topLeft, size)
    }

    @MainActor // todo swift is stupid
    override func setAxFrameDuringTermination(_ topLeft: CGPoint?, _ size: CGSize?) async throws {
        try await macApp.setAxFrameDuringTermination(windowId, topLeft, size)
    }

    override func setSizeAsync(_ size: CGSize) {
        macApp.setSizeAsync(windowId, size)
    }

    override func getTopLeftCorner() async throws -> CGPoint? {
        try await macApp.getTopLeftCorner(windowId)
    }

    override func getRect() async throws -> Rect? {
        try await macApp.getRect(windowId)
    }
}

extension Window {
    @MainActor // todo swift is stupid
    func relayoutWindow(on workspace: Workspace, forceTile: Bool = false) async throws {
        unbindFromParent() // It's important to unbind to get correct data from getBindingData*
        let data = forceTile
            ? getBindingDataForNewTilingWindow(workspace)
            : try await getBindingDataForNewWindow(self.asMacWindow().windowId, self.asMacWindow().macApp, workspace)
        bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
    }
}

// The function is private because it's "unsafe". It requires the window to be in unbound state
@MainActor // todo swift is stupid
private func getBindingDataForNewWindow(_ windowId: UInt32, _ macApp: MacApp, _ workspace: Workspace) async throws -> BindingData {
    if try await !macApp.isWindow(windowId) {
        return BindingData(parent: macosPopupWindowsContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }
    if try await macApp.isDialogHeuristic(windowId) {
        return BindingData(parent: workspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }
    return getBindingDataForNewTilingWindow(workspace)
}

// The function is private because it's unsafe. It requires the window to be in unbound state
@MainActor
private func getBindingDataForNewTilingWindow(_ workspace: Workspace) -> BindingData {
    let mruWindow = workspace.mostRecentWindowRecursive
    if let mruWindow, let tilingParent = mruWindow.parent as? TilingContainer {
        return BindingData(
            parent: tilingParent,
            adaptiveWeight: WEIGHT_AUTO,
            index: mruWindow.ownIndex + 1
        )
    } else {
        return BindingData(
            parent: workspace.rootTilingContainer,
            adaptiveWeight: WEIGHT_AUTO,
            index: INDEX_BIND_LAST
        )
    }
}

extension UnsafeMutableRawPointer {
    var window: MacWindow? { Unmanaged.fromOpaque(self).takeUnretainedValue() }
}

@MainActor
func tryOnWindowDetected(_ window: Window, startup: Bool) async throws {
    switch window.parent.cases {
        case .tilingContainer, .workspace, .macosMinimizedWindowsContainer,
             .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
            try await onWindowDetected(window, startup: startup)
        case .macosPopupWindowsContainer:
            break
    }
}

@MainActor
private func onWindowDetected(_ window: Window, startup: Bool) async throws {
    for callback in config.onWindowDetected where try await callback.matches(window, startup: startup) {
        _ = try await callback.run.runCmdSeq(.defaultEnv.copy(\.windowId, window.windowId), .emptyStdin)
        if !callback.checkFurtherCallbacks {
            return
        }
    }
}

extension WindowDetectedCallback {
    @MainActor
    func matches(_ window: Window, startup: Bool) async throws -> Bool {
        if let startupMatcher = matcher.duringAeroSpaceStartup, startupMatcher != startup {
            return false
        }
        if let regex = matcher.windowTitleRegexSubstring, !(try await window.title).contains(regex) {
            return false
        }
        if let appId = matcher.appId, appId != window.app.id {
            return false
        }
        if let regex = matcher.appNameRegexSubstring, !(window.app.name ?? "").contains(regex) {
            return false
        }
        if let workspace = matcher.workspace, workspace != window.nodeWorkspace?.name {
            return false
        }
        return true
    }
}
