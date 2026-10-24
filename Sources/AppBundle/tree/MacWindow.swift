import AppKit
import Common

final class MacWindow: Window {
    let macApp: MacApp
    private var prevUnhiddenProportionalPositionInsideWorkspaceRect: CGPoint?
    private var lastRestoredProportionalPositionInsideWorkspaceRect: CGPoint?
    private var hiddenInCorner: OptimalHideCorner?
    @MainActor var needsCornerRehide: Bool = false
    var inFlightSetFrameCount: Int = 0
    var lastSetFrameTime: ContinuousClock.Instant = .now - .seconds(10)
    private(set) var lastCommandedTopLeft: CGPoint? = nil
    private(set) var lastCommandedSize: CGSize? = nil

    @MainActor
    var isSuppressingMoveResizeNotifications: Bool {
        inFlightSetFrameCount > 0 || ContinuousClock.now - lastSetFrameTime < .milliseconds(1500) || matchesLastCommandedFrame()
    }

    @MainActor
    func isPointInHideCorner(_ topLeftCorner: CGPoint) -> Bool {
        guard let nodeMonitor else { return false }
        return (topLeftCorner.x >= nodeMonitor.visibleRect.maxX - 2 || topLeftCorner.x <= nodeMonitor.visibleRect.minX + 2) &&
            topLeftCorner.y >= nodeMonitor.visibleRect.maxY - 64
    }

    @MainActor
    func isCurrentlyInHideCorner() -> Bool {
        guard !isUnitTest else { return false }
        if let rect = getCgWindowRect(for: windowId) {
            return isPointInHideCorner(rect.topLeftCorner)
        }
        return false
    }

    @MainActor
    func matchesLastCommandedFrame() -> Bool {
        if isUnitTest { return false }
        if isHiddenInCorner {
            return isCurrentlyInHideCorner()
        }
        guard lastCommandedTopLeft != nil || lastCommandedSize != nil else { return false }
        guard let rect = getCgWindowRect(for: windowId) else { return false }
        if let expectedPos = lastCommandedTopLeft {
            if abs(rect.topLeftX - expectedPos.x) > 4 || abs(rect.topLeftY - expectedPos.y) > 4 {
                return false
            }
        }
        if let expectedSize = lastCommandedSize {
            if abs(rect.width - expectedSize.width) > 4 || abs(rect.height - expectedSize.height) > 4 {
                return false
            }
        }
        return true
    }

    @MainActor
    private init(_ id: UInt32, _ actor: MacApp, lastFloatingSize: CGSize?, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        self.macApp = actor
        super.init(id: id, actor, lastFloatingSize: lastFloatingSize, parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor static var allWindowsMap: [UInt32: MacWindow] = [:]
    @MainActor static var allWindows: [MacWindow] { Array(allWindowsMap.values) }
    private static let savedPositionsUrl = URL(filePath: "/tmp/aerospace_corner_positions.json")
    @MainActor private static var savedCornerPositions: [String: [Double]] = {
        guard let data = try? Data(contentsOf: savedPositionsUrl),
              let dict = try? JSONDecoder().decode([String: [Double]].self, from: data)
        else { return [:] }
        return dict
    }()

    @MainActor
    private static func recordSavedCornerPosition(_ windowId: UInt32, _ prop: CGPoint) {
        let key = String(windowId)
        let val = [Double(prop.x), Double(prop.y)]
        if savedCornerPositions[key] == val { return }
        savedCornerPositions[key] = val
        let snapshot = savedCornerPositions
        Task.detached {
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: savedPositionsUrl, options: .atomic)
            }
        }
    }

    @MainActor
    private static func loadSavedCornerPosition(_ windowId: UInt32) -> CGPoint? {
        guard let arr = savedCornerPositions[String(windowId)], arr.count == 2 else { return nil }
        return CGPoint(x: arr[0], y: arr[1])
    }

    @MainActor
    @discardableResult
    static func getOrRegister(windowId: UInt32, macApp: MacApp) async throws -> MacWindow {
        if let existing = allWindowsMap[windowId] { return existing }
        let rect = try await macApp.getAxRect(windowId, .cancellable)
        let data = try await unbindAndGetBindingDataForNewWindow(
            windowId,
            macApp,
            isStartup
                ? (rect?.center.monitorApproximation ?? mainMonitorInfo).activeWorkspace
                : focus.workspace,
            window: nil,
            .cancellable,
        )

        // atomic synchronous section
        if let existing = allWindowsMap[windowId] { return existing }
        let window = MacWindow(windowId, macApp, lastFloatingSize: rect?.size, parent: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
        allWindowsMap[windowId] = window

        try await debugWindowsIfRecording(window, .cancellable)
        if try await !restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: window) {
            await runOnWindowDetected(ifConventional: window)
            if !isUnitTest,
               !isStartup,
               window.nodeWorkspace?.isVisible == true
            {
                _ = window.focusWindow()
                window.nativeFocus()
            }
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

    func isWindowHeuristic(_ windowLevel: MacOsWindowLevel?, _ cm: CancellationMode) async throws -> Bool { // todo cache
        try await macApp.isWindowHeuristic(windowId, windowLevel, cm)
    }

    func isDialogHeuristic(_ windowLevel: MacOsWindowLevel?, _ cm: CancellationMode) async throws -> Bool { // todo cache
        try await macApp.isDialogHeuristic(windowId, windowLevel, cm)
    }

    func dumpAxInfo(_ cm: CancellationMode) async throws -> [String: Json] {
        try await macApp.dumpWindowAxInfo(windowId: windowId, cm)
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
        let parent = unbindFromParent().parent
        let deadWindowWorkspace = parent.nodeWorkspace
        let focus = focus
        if let deadWindowWorkspace, deadWindowWorkspace == focus.workspace ||
            deadWindowWorkspace == prevFocusedWorkspace && prevFocusedWorkspaceDate.distance(to: .now) < 1
        {
            switch parent.cases {
                case .tilingContainer, .floatingWindowsContainer, .macosHiddenAppsWindowsContainer, .macosFullscreenWindowsContainer:
                    if isUnitTest {
                        let deadWindowFocus = deadWindowWorkspace.toLiveFocus()
                        _ = setFocus(to: deadWindowFocus)
                        if focus.windowOrNil?.app.pid != app.pid {
                            deadWindowFocus.windowOrNil?.nativeFocus()
                        }
                    } else if let sameAppWindow = deadWindowWorkspace.allLeafWindowsRecursiveMru.first(where: { $0.app.pid == app.pid }) {
                        _ = sameAppWindow.focusWindow()
                        sameAppWindow.nativeFocus()
                    } else if focus.windowOrNil == nil || focus.windowOrNil?.app.pid == app.pid {
                        stickyClosedAppPidOnCurrentWorkspace = app.pid
                        _ = setFocus(to: LiveFocus(windowOrNil: nil, workspace: deadWindowWorkspace))
                    }
                case .macosPopupWindowsContainer, // Don't switch back on popup destruction
                     .workspace, // Workspace is invalid parent for windows
                     .macosMinimizedWindowsContainer: // Don't switch back on minimized windows destruction
                    break
            }
        }
    }

    @MainActor override func getTitle(_ cm: CancellationMode) async throws -> String { try await macApp.getAxTitle(windowId, cm) ?? "" }
    override func isMacosFullscreen(_ cm: CancellationMode) async throws -> Bool { try await macApp.isMacosNativeFullscreen(windowId, cm) == true }
    override func isMacosMinimized(_ cm: CancellationMode) async throws -> Bool { try await macApp.isMacosNativeMinimized(windowId, cm) == true }

    @MainActor override func nativeFocus() {
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
            let windowRect: Rect? = if isUnitTest {
                try await getAxRect(.cancellable)
            } else if let cgRect = getCgWindowRect(for: windowId) {
                cgRect
            } else {
                try await getAxRect(.cancellable)
            }
            guard let windowRect else { return }
            // Check for isHiddenInCorner for the second time because of the suspension point above
            if !isHiddenInCorner {
                let topLeftCorner = windowRect.topLeftCorner
                let monitorRect = windowRect.center.monitorApproximation.rect // Similar to layoutFloatingWindow. Non idempotent
                let absolutePoint = topLeftCorner - monitorRect.topLeftCorner
                let proportional = CGPoint(x: absolutePoint.x / monitorRect.width, y: absolutePoint.y / monitorRect.height)
                let isStillClampedInCorner = !isUnitTest && isPointInHideCorner(topLeftCorner)
                if isStillClampedInCorner, let fallback = lastRestoredProportionalPositionInsideWorkspaceRect ?? MacWindow.loadSavedCornerPosition(windowId) {
                    prevUnhiddenProportionalPositionInsideWorkspaceRect = fallback
                    lastRestoredProportionalPositionInsideWorkspaceRect = fallback
                } else {
                    prevUnhiddenProportionalPositionInsideWorkspaceRect = proportional
                    lastRestoredProportionalPositionInsideWorkspaceRect = proportional
                    if !isStillClampedInCorner {
                        MacWindow.recordSavedCornerPosition(windowId, proportional)
                    }
                }
                if isFloating {
                    lastFloatingSize = windowRect.size
                }
            }
        } else if hiddenInCorner == corner {
            if !isUnitTest && ((macApp.isHiddenByAeroSpace && macApp.nsApp.isHidden) || isCurrentlyInHideCorner()) && refreshSessionEvent?.isStartup != true {
                needsCornerRehide = false
                return
            }
            lastCommandedTopLeft = nil
            needsCornerRehide = false
        }
        needsCornerRehide = false
        let p: CGPoint
        switch corner {
            case .bottomLeftCorner:
                let s: CGSize? = if isUnitTest {
                    try await getAxSize(.cancellable)
                } else if let lastFloatingSize {
                    lastFloatingSize
                } else if let lastCommandedSize {
                    lastCommandedSize
                } else if let cgRect = getCgWindowRect(for: windowId) {
                    cgRect.size
                } else {
                    CGSize(width: nodeMonitor.visibleRect.width * 0.5, height: nodeMonitor.visibleRect.height * 0.5)
                }
                guard let s else { fallthrough }
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
        hiddenInCorner = corner
        if isUnitTest || !macApp.nsApp.isHidden {
            setAxFrame(p, nil)
        }
    }

    @MainActor
    func unhideFromCorner() {
        self.hiddenInCorner = nil
        if prevUnhiddenProportionalPositionInsideWorkspaceRect == nil,
           !isUnitTest,
           isCurrentlyInHideCorner(),
           let fallback = lastRestoredProportionalPositionInsideWorkspaceRect ?? MacWindow.loadSavedCornerPosition(windowId)
        {
            prevUnhiddenProportionalPositionInsideWorkspaceRect = fallback
        }
        guard let prevUnhiddenProportionalPositionInsideWorkspaceRect else { return }
        guard let nodeWorkspace else { return } // hiding only makes sense for workspace windows
        guard let parent else { return }

        switch getChildParentRelation(child: self, parent: parent) {
            // Just a small optimization to avoid unnecessary AX calls for non floating windows
            // Tiling windows should be unhidden with layoutRecursive anyway
            case .floatingWindow, .macosNativeHiddenAppWindow:
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
            case .macosNativeFullscreenWindow, .macosNativeMinimizedWindow,
                 .macosPopupWindow, .tiling, .rootTilingContainer, .shimContainerRelation: break
        }

        self.lastRestoredProportionalPositionInsideWorkspaceRect = prevUnhiddenProportionalPositionInsideWorkspaceRect
        self.prevUnhiddenProportionalPositionInsideWorkspaceRect = nil
    }

    override var isHiddenInCorner: Bool {
        prevUnhiddenProportionalPositionInsideWorkspaceRect != nil
    }

    override func getAxSize(_ cm: CancellationMode) async throws -> CGSize? {
        try await macApp.getAxSize(windowId, cm)
    }

    override func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) {
        if !isUnitTest {
            let sameTopLeft = topLeft == nil || topLeft == lastCommandedTopLeft
            let sameSize = size == nil || size == lastCommandedSize
            if sameTopLeft && sameSize && (topLeft != nil || size != nil),
               let rect = getCgWindowRect(for: windowId),
               topLeft.map({ abs(rect.topLeftX - $0.x) <= 4 && abs(rect.topLeftY - $0.y) <= 4 }) ?? true,
               size.map({ abs(rect.width - $0.width) <= 4 && abs(rect.height - $0.height) <= 4 }) ?? true
            {
                return
            }
        }
        if let topLeft { lastCommandedTopLeft = topLeft }
        if let size { lastCommandedSize = size }
        lastSetFrameTime = .now
        inFlightSetFrameCount += 1
        macApp.setAxFrame(windowId, topLeft, size)
    }

    override func getAxRect(_ cm: CancellationMode) async throws -> Rect? {
        try await macApp.getAxRect(windowId, cm)
    }
}

extension Window {
    @MainActor
    func relayoutWindow(on workspace: Workspace, _ cm: CancellationMode, forceTile: Bool = false) async throws {
        let data = forceTile
            ? unbindAndGetBindingDataForNewTilingWindow(workspace, window: self)
            : try await unbindAndGetBindingDataForNewWindow(self.asMacWindow().windowId, self.asMacWindow().macApp, workspace, window: self, cm)
        bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
    }
}

// The function is private because it's unsafe. It leaves the window in unbound state
@MainActor
private func unbindAndGetBindingDataForNewWindow(_ windowId: UInt32, _ macApp: MacApp, _ workspace: Workspace, window: Window?, _ cm: CancellationMode) async throws -> BindingData {
    let windowLevel = getWindowLevel(for: windowId)
    return switch try await macApp.getAxUiElementWindowType(windowId, windowLevel, cm) {
        case .popup: BindingData(parent: macosPopupWindowsContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        case .dialog: BindingData(parent: workspace.floatingWindowsContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        case .window: unbindAndGetBindingDataForNewTilingWindow(workspace, window: window)
    }
}

// The function is private because it's unsafe. It leaves the window in unbound state
@MainActor
private func unbindAndGetBindingDataForNewTilingWindow(_ workspace: Workspace, window: Window?) -> BindingData {
    window?.unbindFromParent() // It's important to unbind to get correct data from below
    let mruWindow = workspace.mostRecentWindowRecursive
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
func runOnWindowDetected(ifConventional window: Window) async {
    switch window.windowParentCases {
        case .tilingContainer, .floatingWindowsContainer, .macosMinimizedWindowsContainer,
             .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
            let layout = global_layoutForNextDetectedWindow
            global_layoutForNextDetectedWindow = nil
            defer {
                if let layout {
                    await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [layout]))
                        .run(.defaultEnv.withWindowId(window.windowId), .emptyStdin)
                }
            }
            if let layout {
                await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [layout]))
                    .run(.defaultEnv.withWindowId(window.windowId), .emptyStdin)
            }
            _ = await onWindowDetected(.defaultEnv, CmdIoImpl.emptyStdinIgnoringOut, window)
        case .macosPopupWindowsContainer, .unbound:
            break
    }
}

@MainActor
func onWindowDetected(_ env: CmdEnv, _ io: CmdIo, _ window: Window) async -> Int32ExitCode {
    broadcastEvent(.windowDetected(
        windowId: window.windowId,
        workspace: window.nodeWorkspace?.name,
        appBundleId: window.app.rawAppBundleId,
        appName: window.app.name,
    ))
    var lastExitCode = Int32ExitCode.succ
    for callback in config.onWindowDetected where await callback.matches(window) {
        lastExitCode = await callback.run.run(env.withWindowId(window.windowId), io)
        if !callback.checkFurtherCallbacks {
            return lastExitCode
        }
    }
    return lastExitCode
}

extension WindowDetectedCallback {
    @MainActor
    func matches(_ window: Window) async -> Bool {
        switch self.matcher {
            case .legacy(let matcher):
                if let startupMatcher = matcher.duringAeroSpaceStartup, startupMatcher != isStartup {
                    return false
                }
                if let regex = matcher.windowTitleRegexSubstring, (try? await window.getTitle(.nonCancellable))?.contains(caseInsensitiveRegex: regex) != true {
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
            case .command(let command):
                return await command.run(.defaultEnv.withWindowId(window.windowId), .emptyStdin).exitCode.rawValue == 0
        }
    }
}
