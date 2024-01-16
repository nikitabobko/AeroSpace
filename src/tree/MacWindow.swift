import Common

final class MacWindow: Window, CustomStringConvertible {
    let axWindow: AXUIElement
    private let macApp: MacApp
    // todo take into account monitor proportions
    private var prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect: CGPoint?
    fileprivate var previousSize: CGSize?
    private var axObservers: [AxObserverWrapper] = [] // keep observers in memory

    private init(_ id: CGWindowID, _ app: MacApp, _ axWindow: AXUIElement, parent: NonLeafTreeNode, adaptiveWeight: CGFloat, index: Int) {
        self.axWindow = axWindow
        self.macApp = app
        super.init(id: id, app, lastFloatingSize: axWindow.get(Ax.sizeAttr), parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    private static var allWindowsMap: [CGWindowID: MacWindow] = [:]
    static var allWindows: [MacWindow] { Array(allWindowsMap.values) }

    static func get(app: MacApp, axWindow: AXUIElement, startup: Bool) -> MacWindow? {
        if !isWindow(axWindow, app) { return nil }
        guard let id = axWindow.windowId() else { return nil }
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
                onWindowDetected(window, startup: startup)
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
            ("windowId", String(windowId))
        ].map { "\($0.0): '\(String(describing: $0.1))'" }.joined(separator: ", ")
        return "Window(\(description))"
    }

    func garbageCollect() {
        debug("garbageCollectWindow of \(app.name ?? "NO TITLE")")
        if MacWindow.allWindowsMap.removeValue(forKey: windowId) == nil {
            return
        }
        let workspace = unbindFromParent().parent.workspace.name
        for obs in axObservers {
            AXObserverRemoveNotification(obs.obs, obs.ax, obs.notif)
        }
        axObservers = []
        // todo the if is an approximation to filter out cases when window just closed itself (or was killed remotely)
        //  we might want to track the time of the latest workspace switch to make the approximation more accurate
        if workspace == previousFocusedWorkspaceName || workspace == focusedWorkspaceName {
            refreshSession(forceFocus: true) {
                _ = WorkspaceCommand.run(.focused, workspace)
            }
        }
    }

    private func observe(_ handler: AXObserverCallback, _ notifKey: String) -> Bool {
        guard let observer = AXObserver.observe(app.pid, notifKey, axWindow, handler, data: self) else { return false }
        axObservers.append(AxObserverWrapper(obs: observer, ax: axWindow, notif: notifKey as CFString))
        return true
    }

    override var title: String? {
        axWindow.get(Ax.titleAttr)
    }

    @discardableResult
    override func nativeFocus() -> Bool { // todo make focus reliable: make async + active waiting
        // Raise firstly to make sure that by that time we activate the app, particular window would be already on top
        axWindow.raise() && macApp.nsApp.activate(options: .activateIgnoringOtherApps)
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
            prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect =
                    topLeftCorner - workspace.monitor.rect.topLeftCorner
        }
        setTopLeftCorner(allMonitorsRectsUnion.bottomRightCorner)
    }

    func unhideViaEmulation() {
        guard let prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect else { return }

        setTopLeftCorner(workspace.monitor.rect.topLeftCorner + prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect)

        self.prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect = nil
    }

    override var isHiddenViaEmulation: Bool {
        prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect != nil
    }

    override func setSize(_ size: CGSize) {
        disableAnimations {
            previousSize = getSize()
            axWindow.set(Ax.sizeAttr, size)
        }
    }

    override func getSize() -> CGSize? {
        axWindow.get(Ax.sizeAttr)
    }

    override func setTopLeftCorner(_ point: CGPoint) {
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
    private func disableAnimations(_ body: () -> Void) {
        let app = (app as! MacApp).axApp
        let wasEnabled = app.get(Ax.enhancedUserInterfaceAttr) == true
        if wasEnabled {
            app.set(Ax.enhancedUserInterfaceAttr, false)
        }
        body()
        if wasEnabled {
            app.set(Ax.enhancedUserInterfaceAttr, true)
        }
    }
}

private func isWindow(_ axWindow: AXUIElement, _ app: MacApp) -> Bool {
    let subrole = axWindow.get(Ax.subroleAttr)
    // Sonoma (macOS 14) keyboard layout switch
    if axWindow.get(Ax.identifierAttr) == "AXCursorActionsWindow" && subrole == kAXDialogSubrole {
        return false
    }
    if app.nsApp.bundleIdentifier == "com.jetbrains.toolbox" {
        return false
    }
    return subrole == kAXStandardWindowSubrole ||
        subrole == kAXDialogSubrole || // macOS native file picker ("Open..." menu) (kAXDialogSubrole value)
        subrole == kAXFloatingWindowSubrole || // telegram image viewer
        app.id == "com.apple.finder" && subrole == "Quick Look" // Finder preview (hit space) is a floating window
}

private func shouldFloat(_ axWindow: AXUIElement, _ app: MacApp) -> Bool { // Note: a lot of windows don't have title on startup
    // Don't tile:
    // - Chrome cmd+f window ("AXUnknown" value)
    // - login screen (Yes fuck, it's also a window from Apple's API perspective) ("AXUnknown" value)
    // - XCode "Build succeeded" popup
    // - IntelliJ tooltips, context menus, drop downs
    // - macOS native file picker (IntelliJ -> "Open...") (kAXDialogSubrole value)
    //
    // Minimized windows or windows of a hidden app have subrole "AXDialog"
    if axWindow.get(Ax.subroleAttr) != kAXStandardWindowSubrole  {
        return true
    }
    // Heuristic: float windows without maximize button (such windows are not designed to be big)
    // - IntelliJ various dialogs (Rebase..., Edit commit message, Settings, Project structure)
    // - Finder copy file dialog
    // - System Settings
    // - Apple logo -> About this Mac
    // - Calculator
    // - Battle.net login dialog
    if axWindow.get(Ax.fullscreenButtonAttr) == nil &&
           app.id != "com.google.Chrome" && // "Drag out" a tab out of Chrome window
           app.id != "org.videolan.vlc" && // VLC has its own implementation of fullscreen
           app.id != "com.valvesoftware.steam" && // Steam doesn't show fullscreen button
           app.id != "org.gimp.gimp-2.10" && // Gimp doesn't show fullscreen button

           // Terminal apps and Emacs have an option to hide their title bars
           app.id != "org.alacritty" &&
           app.id != "com.github.wez.wezterm" &&
           app.id != "com.googlecode.iterm2" &&
           app.id != "org.gnu.Emacs" {
        return true
    }
    return false
}

private func getBindingDataForNewWindow(_ axWindow: AXUIElement, _ workspace: Workspace, _ app: MacApp) -> BindingData {
    shouldFloat(axWindow, app)
        ? BindingData(parent: workspace as NonLeafTreeNode, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        : getBindingDataForNewTilingWindow(workspace)
}

func getBindingDataForNewTilingWindow(_ workspace: Workspace) -> BindingData {
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

private func onWindowDetected(_ window: Window, startup: Bool) {
    check(Thread.current.isMainThread)
    for callback in config.onWindowDetected {
        if callback.matches(window, startup: startup) {
            _ = callback.run.run(CommandMutableState(.window(window)))
            if !callback.checkFurtherCallbacks {
                return
            }
        }
    }
}

extension WindowDetectedCallback {
    func matches(_ window: Window, startup: Bool) -> Bool {
        if let startupMatcher = matcher.duringAeroSpaceStartup, startupMatcher != startup {
            return false
        }
        if let regex = matcher.windowTitleRegexSubstring, !(window.title ?? "").contains(regex) {
            return false
        }
        if let appId = matcher.appId, appId != window.app.id {
            return false
        }
        if let regex = matcher.appNameRegexSubstring, !(window.app.name ?? "").contains(regex) {
            return false
        }
        return true
    }
}
