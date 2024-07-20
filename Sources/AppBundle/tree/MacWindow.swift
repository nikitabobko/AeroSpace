import AppKit
import Common

final class MacWindow: Window, CustomStringConvertible {
    let axWindow: AXUIElement
    let macApp: MacApp
    // todo take into account monitor proportions
    private var prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect: CGPoint?
    fileprivate var previousSize: CGSize?
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
                startup ? (axWindow.center?.monitorApproximation ?? mainMonitor).activeWorkspace : Workspace.focused,
                app
            )
            let window = MacWindow(id, app, axWindow, parent: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)

            if window.observe(destroyedObs, kAXUIElementDestroyedNotification) &&
                    window.observe(refreshObs, kAXWindowDeminiaturizedNotification) &&
                    window.observe(refreshObs, kAXWindowMiniaturizedNotification) &&
                    window.observe(movedObs, kAXMovedNotification) &&
                    window.observe(resizedObs, kAXResizedNotification) {
                debug("New window detected: \(window)")
                allWindowsMap[id] = window
                debugWindowsIfRecording(window)
                tryOnWindowDetected(window, startup: startup)
                return window
            } else {
                window.garbageCollect()
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

    func garbageCollect() {
        debug("garbageCollectWindow of \(app.name ?? "NO TITLE")")
        if MacWindow.allWindowsMap.removeValue(forKey: windowId) == nil {
            return
        }
        let parent = unbindFromParent().parent
        let workspace = parent.workspace
        for obs in axObservers {
            AXObserverRemoveNotification(obs.obs, obs.ax, obs.notif)
        }
        axObservers = []
        // todo the if is an approximation to filter out cases when window just closed itself (or was killed remotely)
        //  we might want to track the time of the latest workspace switch to make the approximation more accurate
        let focus = focus
        if let workspace, workspace == focus.workspace || workspace == prevFocusedWorkspace {
            switch parent.cases {
                case .tilingContainer, .workspace, .macosInvisibleWindowsContainer, .macosFullscreenWindowsContainer:
                    refreshSession(forceFocus: focus.windowOrNil?.app != app) {
                        _ = workspace.focusWorkspace()
                    }
                case .macosPopupWindowsContainer:
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
        return AXUIElementPerformAction(closeButton, kAXPressAction as CFString) == AXError.success
    }

    func hideViaEmulation() {
        //guard let monitorApproximation else { return }
        // Don't accidentally override prevUnhiddenEmulationPosition in case of subsequent
        // `hideEmulation` calls
        if !isHiddenViaEmulation {
            debug("hideViaEmulation: Hide \(self)")
            guard let topLeftCorner = getTopLeftCorner() else { return }
            guard let workspace else { return } // hiding only makes sense for workspace windows
            prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect =
                topLeftCorner - workspace.workspaceMonitor.rect.topLeftCorner
        }
        _ = setTopLeftCorner(allMonitorsRectsUnion.bottomRightCorner)
    }

    func unhideViaEmulation() {
        guard let prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect else { return }
        guard let workspace else { return } // hiding only makes sense for workspace windows

        _ = setTopLeftCorner(workspace.workspaceMonitor.rect.topLeftCorner + prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect)

        self.prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect = nil
    }

    override var isHiddenViaEmulation: Bool {
        prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect != nil
    }

    override func setSize(_ size: CGSize) -> Bool {
        disableAnimations {
            previousSize = getSize()
            return axWindow.set(Ax.sizeAttr, size)
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
            (axWindow.get(Ax.titleAttr) ?? "").isEmpty {
        return false
    }
    return subrole == kAXStandardWindowSubrole ||
        subrole == kAXDialogSubrole || // macOS native file picker ("Open..." menu) (kAXDialogSubrole value)
        subrole == kAXFloatingWindowSubrole || // telegram image viewer
        app.id == "com.apple.finder" && subrole == "Quick Look" // Finder preview (hit space) is a floating window
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
            app.id != "com.github.wez.wezterm" &&
            app.id != "com.googlecode.iterm2" &&
            app.id != "org.gnu.Emacs" {
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
    let mruWindow = workspace.mostRecentWindow
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

private func destroyedObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    data?.window?.garbageCollect()
    refreshAndLayout()
}

func tryOnWindowDetected(_ window: Window, startup: Bool) {
    switch window.parent.cases {
        case .tilingContainer, .workspace, .macosInvisibleWindowsContainer, .macosFullscreenWindowsContainer:
            onWindowDetected(window, startup: startup)
        case .macosPopupWindowsContainer:
            break
    }
}

private func onWindowDetected(_ window: Window, startup: Bool) {
    check(Thread.current.isMainThread)
    for callback in config.onWindowDetected where callback.matches(window, startup: startup) {
        _ = callback.run.run(CommandMutableState(.window(window)))
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
        if let workspace = matcher.workspace, workspace != window.workspace?.name {
            return false
        }
        return true
    }
}
