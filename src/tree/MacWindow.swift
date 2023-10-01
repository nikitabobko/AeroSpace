final class MacWindow: Window {
    let axWindow: AXUIElement
    let app: MacApp
    private var prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect: CGPoint?
    // todo redundant?
    private var prevUnhiddenEmulationSize: CGSize?
    fileprivate var previousSize: CGSize?
    private var axObservers: [AxObserverWrapper] = [] // keep observers in memory

    private init(_ id: CGWindowID, _ app: MacApp, _ axWindow: AXUIElement, parent: TreeNode, adaptiveWeight: CGFloat) {
        self.app = app
        self.axWindow = axWindow
        super.init(id: id, parent: parent, adaptiveWeight: adaptiveWeight)
    }

    private static var allWindowsMap: [CGWindowID: MacWindow] = [:]
    static var allWindows: [MacWindow] { Array(allWindowsMap.values) }

    static func get(app: MacApp, axWindow: AXUIElement) -> MacWindow? {
        guard let id = axWindow.windowId() else { return nil }
        // The app is still loading (e.g. IntelliJ IDEA)
        // Or it's tooltips, context menus, and drop downs (e.g. IntelliJ IDEA)
        if axWindow.get(Ax.titleAttr).isNilOrEmpty {
            return nil
        }
        if let existing = allWindowsMap[id] {
            return existing
        } else {
            let focusedWorkspace = Workspace.focused
            let workspace: Workspace
            // todo rewrite. Window is appeared on empty space
            if focusedWorkspace == currentEmptyWorkspace &&
                       focusedApp == app &&
                       app.axFocusedWindow?.windowId() == axWindow.windowId() {
                workspace = currentEmptyWorkspace
            } else {
                guard let topLeftCorner = axWindow.get(Ax.topLeftCornerAttr) else { return nil }
                workspace = topLeftCorner.monitorApproximation.getActiveWorkspace()
            }
            let shouldFloat = shouldFloat(axWindow)
            let parent: TreeNode
            if shouldFloat || config.debugAllWindowsAreFloating {
                parent = workspace
            } else {
                let tilingParent = workspace.mruWindows.mostRecent?.parent as? TilingContainer ?? workspace.rootTilingContainer
                parent = tilingParent
            }
            let window = MacWindow(id, app, axWindow, parent: parent, adaptiveWeight: WEIGHT_AUTO)

            if window.observe(refreshObs, kAXUIElementDestroyedNotification) &&
                       window.observe(refreshObs, kAXWindowDeminiaturizedNotification) &&
                       window.observe(refreshObs, kAXWindowMiniaturizedNotification) &&
                       window.observe(refreshObs, kAXMovedNotification) &&
                       window.observe(refreshObs, kAXResizedNotification) {
                debug("New window detected: \(window.title ?? "")")
                allWindowsMap[id] = window
                return window
            } else {
                window.garbageCollect()
                return nil
            }
        }
    }

    func garbageCollect() {
        debug("garbageCollectWindow of \(app.title ?? "NO TITLE")")
        MacWindow.allWindowsMap.removeValue(forKey: windowId)
        unbindFromParent()
        for obs in axObservers {
            AXObserverRemoveNotification(obs.obs, obs.ax, obs.notif)
        }
        axObservers = []
    }

    private func observe(_ handler: AXObserverCallback, _ notifKey: String) -> Bool {
        guard let observer = AXObserver.observe(app.nsApp.processIdentifier, notifKey, axWindow, handler) else { return false }
        axObservers.append(AxObserverWrapper(obs: observer, ax: axWindow, notif: notifKey as CFString))
        return true
    }

    override var title: String? {
        axWindow.get(Ax.titleAttr)
    }

    @discardableResult
    override func focus() -> Bool {
        if app.nsApp.activate(options: .activateIgnoringOtherApps) && axWindow.raise() {
            workspace.mruWindows.pushOrRaise(self)
            return true
        } else {
            return false
        }
    }

    func close() -> Bool {
        guard let closeButton = axWindow.get(Ax.closeButtonAttr) else { return false }
        return AXUIElementPerformAction(closeButton, kAXPressAction as CFString) == AXError.success
    }

    // todo current approach breaks mission control (three fingers up the trackpad). Or is it only because of IDEA?
    // todo hypnotize: change size to cooperate with mission control (make it configurable)
    func hideViaEmulation() {
        //guard let monitorApproximation else { return }
        // Don't accidentally override prevUnhiddenEmulationPosition in case of subsequent
        // `hideEmulation` calls
        if !isHiddenViaEmulation {
            debug("Hide \(app.title) - \(title)")
            guard let topLeftCorner = getTopLeftCorner() else { return }
            guard let size = getSize() else { return }
            prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect =
                    topLeftCorner - workspace.assignedMonitorOfNotEmptyWorkspace.rect.topLeftCorner
            prevUnhiddenEmulationSize = size
        }
        setTopLeftCorner(allMonitorsRectsUnion.bottomRightCorner)
    }

    func unhideViaEmulation() {
        precondition((prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect != nil) == (prevUnhiddenEmulationSize != nil))
        guard let prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect else { return }
        guard let prevUnhiddenEmulationSize else { return }

        setTopLeftCorner(workspace.assignedMonitorOfNotEmptyWorkspace.rect.topLeftCorner + prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect)
        // Restore the size because during hiding the window can end up on different monitor with different density,
        // size, etc. And macOS can change the size of the window when the window is moved on different monitor in that
        // case. So we need to restore the size of the window
        setSize(prevUnhiddenEmulationSize)

        self.prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect = nil
        self.prevUnhiddenEmulationSize = nil
    }

    var isHiddenViaEmulation: Bool {
        precondition((prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect != nil) == (prevUnhiddenEmulationSize != nil))
        return prevUnhiddenEmulationPositionRelativeToWorkspaceAssignedRect != nil
    }

    override func setSize(_ size: CGSize) {
        previousSize = getSize()
        axWindow.set(Ax.sizeAttr, size)
    }

    func getSize() -> CGSize? {
        axWindow.get(Ax.sizeAttr)
    }

    override func setTopLeftCorner(_ point: CGPoint) {
        axWindow.set(Ax.topLeftCornerAttr, point)
    }

    private func getTopLeftCorner() -> CGPoint? {
        axWindow.get(Ax.topLeftCornerAttr)
    }

    override func getRect() -> Rect? {
        guard let topLeftCorner = getTopLeftCorner() else { return nil }
        guard let size = getSize() else { return nil }
        return Rect(topLeftX: topLeftCorner.x, topLeftY: topLeftCorner.y, width: size.width, height: size.height)
    }

    static func garbageCollectClosedWindows() {
        for window in allWindows {
            if window.axWindow.windowId() == nil {
                window.garbageCollect()
            }
        }
    }
}

func shouldFloat(_ axWindow: AXUIElement) -> Bool { // todo
    false
}
