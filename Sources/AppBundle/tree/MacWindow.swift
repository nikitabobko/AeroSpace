import AppKit
import Common

final class MacWindow: Window, CustomStringConvertible {
    let axWindow: AXUIElement
    let macApp: MacApp
    // todo take into account monitor proportions
    private var prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect: CGPoint?
    private var axObservers: [AxObserverWrapper] = [] // keep observers in memory

    private init(_ id: CGWindowID, _ app: MacApp, _ axWindow: AXUIElement, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        self.axWindow = axWindow
        self.macApp = app
        super.init(id: id, app, lastFloatingSize: axWindow.get(Ax.sizeAttr), parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    static var allWindowsMap: [CGWindowID: MacWindow] = [:]
    static var allWindows: [MacWindow] { Array(allWindowsMap.values) }

    static func get(app: MacApp, axWindow: AXUIElement, startup: Bool) -> MacWindow? {
        guard let id = axWindow.containingWindowId() else { return nil }
        if let existing = allWindowsMap[id] {
            return existing
        } else {
            let data = getBindingDataForNewWindow(
                axWindow,
                startup ? (axWindow.center?.monitorApproximation ?? mainMonitor).activeWorkspace : focus.workspace,
                app
            )
            let window = MacWindow(id, app, axWindow, parent: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)

            if window.observe(refreshObs, kAXUIElementDestroyedNotification) &&
                window.observe(refreshObs, kAXWindowDeminiaturizedNotification) &&
                window.observe(refreshObs, kAXWindowMiniaturizedNotification) &&
                window.observe(movedObs, kAXMovedNotification) &&
                window.observe(resizedObs, kAXResizedNotification)
            {
                allWindowsMap[id] = window
                debugWindowsIfRecording(window)
                if !restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: window) {
                    tryOnWindowDetected(window, startup: startup)
                }
                return window
            } else {
                window.garbageCollect(skipClosedWindowsCache: true)
                return nil
            }
        }
    }

    var description: String {
        let description = [
            ("title", title),
            ("role", axWindow.get(Ax.roleAttr)),
            ("subrole", axWindow.get(Ax.subroleAttr)),
            ("identifier", axWindow.get(Ax.identifierAttr)),
            ("modal", axWindow.get(Ax.modalAttr).map { String($0) } ?? ""),
            ("windowId", String(windowId)),
        ].map { "\($0.0): '\(String(describing: $0.1))'" }.joined(separator: ", ")
        return "Window(\(description))"
    }

    // skipClosedWindowsCache is an optimization when it's definitely not necessary to cache closed window.
    //                        If you are unsure, it's better to pass `false`
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
        // todo the if is an approximation to filter out cases when window just closed itself (or was killed remotely)
        //  we might want to track the time of the latest workspace switch to make the approximation more accurate
        let focus = focus
        if let deadWindowWorkspace, deadWindowWorkspace == focus.workspace || deadWindowWorkspace == prevFocusedWorkspace {
            switch parent.cases {
                case .tilingContainer, .workspace, .macosHiddenAppsWindowsContainer, .macosFullscreenWindowsContainer:
                    let deadWindowFocus = deadWindowWorkspace.toLiveFocus()
                    _ = setFocus(to: deadWindowFocus)
                    if focus.windowOrNil?.app != app {
                        deadWindowFocus.windowOrNil?.nativeFocus() // force focus
                    }
                case .macosPopupWindowsContainer, .macosMinimizedWindowsContainer:
                    break // Don't switch back on popup destruction
            }
        }
    }

    private func observe(_ handler: AXObserverCallback, _ notifKey: String) -> Bool {
        guard let observer = AXObserver.observe(app.pid, notifKey, axWindow, handler, data: self) else { return false }
        axObservers.append(AxObserverWrapper(obs: observer, ax: axWindow, notif: notifKey as CFString))
        return true
    }

    override var title: String { axWindow.get(Ax.titleAttr) ?? "" }
    override var isMacosFullscreen: Bool { axWindow.get(Ax.isFullscreenAttr) == true }
    override var isMacosMinimized: Bool { axWindow.get(Ax.minimizedAttr) == true }

    @discardableResult
    override func nativeFocus() -> Bool {
        // Raise firstly to make sure that by the time we activate the app, the window would be already on top
        axWindow.set(Ax.isMainAttr, true) &&
            axWindow.raise() &&
            macApp.nsApp.activate(options: .activateIgnoringOtherApps)
    }

    override func close() -> Bool {
        guard let closeButton = axWindow.get(Ax.closeButtonAttr) else { return false }
        if AXUIElementPerformAction(closeButton, kAXPressAction as CFString) != AXError.success { return false }
        garbageCollect(skipClosedWindowsCache: true)
        return true
    }

    func hideInCorner(_ corner: OptimalHideCorner) {
        guard let nodeMonitor else { return }
        // Don't accidentally override prevUnhiddenEmulationPosition in case of subsequent
        // `hideEmulation` calls
        if !isHiddenInCorner {
            guard let topLeftCorner = getTopLeftCorner() else { return }
            guard let nodeWorkspace else { return } // hiding only makes sense for workspace windows
            prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect =
                topLeftCorner - nodeWorkspace.workspaceMonitor.rect.topLeftCorner
        }
        let p: CGPoint
        switch corner {
            case .bottomLeftCorner:
                guard let s = getSize() else { fallthrough }
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
        _ = setTopLeftCorner(p)
    }

    func unhideFromCorner() {
        guard let prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect else { return }
        guard let nodeWorkspace else { return } // hiding only makes sense for workspace windows

        switch getChildParentRelation(child: self, parent: parent) {
            // Just a small optimization to avoid unnecessary AX calls for non floating windows
            // Tiling windows should be unhidden with layoutRecursive anyway
            case .floatingWindow:
                _ = setTopLeftCorner(nodeWorkspace.workspaceMonitor.rect.topLeftCorner + prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect)
            case .macosNativeFullscreenWindow, .macosNativeHiddenAppWindow, .macosNativeMinimizedWindow,
                 .macosPopupWindow, .tiling, .rootTilingContainer, .shimContainerRelation: break
        }

        self.prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect = nil
    }

    override var isHiddenInCorner: Bool {
        prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect != nil
    }

    override func setSize(_ size: CGSize) -> Bool {
        disableAnimations {
            axWindow.set(Ax.sizeAttr, size)
        }
    }

    override func getSize() -> CGSize? {
        axWindow.get(Ax.sizeAttr)
    }

    override func setTopLeftCorner(_ point: CGPoint) -> Bool {
        disableAnimations {
            axWindow.set(Ax.topLeftCornerAttr, point)
        }
    }

    override func getTopLeftCorner() -> CGPoint? {
        axWindow.get(Ax.topLeftCornerAttr)
    }

    override func getRect() -> Rect? {
        guard let topLeftCorner = getTopLeftCorner() else { return nil }
        guard let size = getSize() else { return nil }
        return Rect(topLeftX: topLeftCorner.x, topLeftY: topLeftCorner.y, width: size.width, height: size.height)
    }

    // Some undocumented magic
    // References: https://github.com/koekeishiya/yabai/commit/3fe4c77b001e1a4f613c26f01ea68c0f09327f3a
    //             https://github.com/rxhanson/Rectangle/pull/285
    private func disableAnimations<T>(_ body: () -> T) -> T {
        let app = (app as! MacApp).axApp
        let wasEnabled = app.get(Ax.enhancedUserInterfaceAttr) == true
        if wasEnabled {
            app.set(Ax.enhancedUserInterfaceAttr, false)
        }
        let result = body()
        if wasEnabled {
            app.set(Ax.enhancedUserInterfaceAttr, true)
        }
        return result
    }
}

/// Alternative name: !isPopup
func isWindow(_ axWindow: AXUIElement, _ app: MacApp) -> Bool {
    let subrole = axWindow.get(Ax.subroleAttr)

    // Try to filter out incredibly weird popup like AXWindows without any buttons.
    // E.g.
    // - Sonoma (macOS 14) keyboard layout switch
    // - IntelliJ context menu (right mouse click)
    // - Telegram context menu (right mouse click)
    if axWindow.get(Ax.closeButtonAttr) == nil &&
        axWindow.get(Ax.fullscreenButtonAttr) == nil &&
        axWindow.get(Ax.zoomButtonAttr) == nil &&
        axWindow.get(Ax.minimizeButtonAttr) == nil &&

        axWindow.get(Ax.isFocused) == false &&  // Three different ways to detect if the window is not focused
        axWindow.get(Ax.isMainAttr) == false &&
        app.getFocusedAxWindow()?.containingWindowId() != axWindow.containingWindowId() &&

        subrole != kAXStandardWindowSubrole &&
        (axWindow.get(Ax.titleAttr) ?? "").isEmpty
    {
        return false
    }
    return subrole == kAXStandardWindowSubrole ||
        subrole == kAXDialogSubrole || // macOS native file picker ("Open..." menu) (kAXDialogSubrole value)
        subrole == kAXFloatingWindowSubrole || // telegram image viewer
        app.id == "com.apple.finder" && subrole == "Quick Look" || // Finder preview (hit space) is a floating window

        // Firefox non-native video fullscreen
        // about:config -> full-screen-api.macos-native-full-screen -> false
        app.id == "org.mozilla.firefox" && subrole == kAXUnknownSubrole
}

func shouldFloat(_ axWindow: AXUIElement, _ app: MacApp) -> Bool { // Note: a lot of windows don't have title on startup
    // Don't tile:
    // - Chrome cmd+f window ("AXUnknown" value)
    // - login screen (Yes fuck, it's also a window from Apple's API perspective) ("AXUnknown" value)
    // - XCode "Build succeeded" popup
    // - IntelliJ tooltips, context menus, drop downs
    // - macOS native file picker (IntelliJ -> "Open...") (kAXDialogSubrole value)
    //
    // Minimized windows or windows of a hidden app have subrole "AXDialog"
    if axWindow.get(Ax.subroleAttr) != kAXStandardWindowSubrole {
        return true
    }
    // Firefox: Picture in Picture window doesn't have minimize button.
    if app.id == "org.mozilla.firefox" && axWindow.get(Ax.minimizeButtonAttr)?.get(Ax.enabledAttr) != true {
        return true
    }
    // Heuristic: float windows without fullscreen button (such windows are not designed to be big)
    // - IntelliJ various dialogs (Rebase..., Edit commit message, Settings, Project structure)
    // - Finder copy file dialog
    // - System Settings
    // - Apple logo -> About this Mac
    // - Calculator
    // - Battle.net login dialog
    // Fullscreen button is presented but disabled:
    // - Safari -> Pinterest -> Log in with Google
    // - Kap screen recorder https://github.com/wulkano/Kap
    // - flameshot? https://github.com/nikitabobko/AeroSpace/issues/112
    // - Drata Agent https://github.com/nikitabobko/AeroSpace/issues/134
    if !isFullscreenable(axWindow) &&
        app.id != "com.google.Chrome" && // "Drag out" a tab out of Chrome window
        app.id != "org.gimp.gimp-2.10" && // Gimp doesn't show fullscreen button
        app.id != "com.apple.ActivityMonitor" && // Activity Monitor doesn't show fullscreen button

        // Terminal apps and Emacs have an option to hide their title bars
        app.id != "org.alacritty" &&
        app.id != "net.kovidgoyal.kitty" && // ~/.config/kitty/kitty.conf: hide_window_decorations titlebar-and-corners
        app.id != "com.mitchellh.ghostty" && // ~/.config/ghostty/config: window-decoration = false
        app.id != "com.github.wez.wezterm" &&
        app.id != "com.googlecode.iterm2" &&
        app.id != "org.gnu.Emacs"
    {
        return true
    }
    return false
}

private func isFullscreenable(_ axWindow: AXUIElement) -> Bool {
    if let fullscreenButton = axWindow.get(Ax.fullscreenButtonAttr) {
        return fullscreenButton.get(Ax.enabledAttr) == true
    }
    return false
}

extension Window {
    func relayoutWindow(on workspace: Workspace, forceTile: Bool = false) {
        unbindFromParent() // It's important to unbind to get correct data from getBindingData*
        let data = forceTile
            ? getBindingDataForNewTilingWindow(workspace)
            : getBindingDataForNewWindow(self.asMacWindow().axWindow, workspace, self.macAppUnsafe)
        bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
    }
}

// The function is private because it's "unsafe". It requires the window to be in unbound state
private func getBindingDataForNewWindow(_ axWindow: AXUIElement, _ workspace: Workspace, _ app: MacApp) -> BindingData {
    if !isWindow(axWindow, app) {
        return BindingData(parent: macosPopupWindowsContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }
    if shouldFloat(axWindow, app) {
        return BindingData(parent: workspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }
    return getBindingDataForNewTilingWindow(workspace)
}

// The function is private because it's "unsafe". It requires the window to be in unbound state
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

func tryOnWindowDetected(_ window: Window, startup: Bool) {
    switch window.parent.cases {
        case .tilingContainer, .workspace, .macosMinimizedWindowsContainer,
             .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
            onWindowDetected(window, startup: startup)
        case .macosPopupWindowsContainer:
            break
    }
}

private func onWindowDetected(_ window: Window, startup: Bool) {
    check(Thread.current.isMainThread)
    for callback in config.onWindowDetected where callback.matches(window, startup: startup) {
        _ = callback.run.runCmdSeq(.defaultEnv.copy(\.windowId, window.windowId), .emptyStdin)
        if !callback.checkFurtherCallbacks {
            return
        }
    }
}

extension WindowDetectedCallback {
    func matches(_ window: Window, startup: Bool) -> Bool {
        if let startupMatcher = matcher.duringAeroSpaceStartup, startupMatcher != startup {
            return false
        }
        if let regex = matcher.windowTitleRegexSubstring, !(window.title).contains(regex) {
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
