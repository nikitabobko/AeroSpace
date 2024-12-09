import AppKit

final class MacApp: AbstractApp {
    let nsApp: NSRunningApplication
    let axApp: AXUIElement
    let isZoom: Bool

    private var axObservers: [AxObserverWrapper] = [] // keep observers in memory

    private init(_ nsApp: NSRunningApplication, _ axApp: AXUIElement) {
        self.nsApp = nsApp
        self.axApp = axApp
        self.isZoom = nsApp.bundleIdentifier == "us.zoom.xos"
        super.init(pid: nsApp.processIdentifier, id: nsApp.bundleIdentifier)
    }

    static var allAppsMap: [pid_t: MacApp] = [:]

    fileprivate static func get(_ nsApp: NSRunningApplication) -> MacApp? {
        // Don't perceive any of the lock screen windows as real windows
        // Otherwise, false positive ax notifications might trigger that lead to gcWindows
        if nsApp.bundleIdentifier == lockScreenAppBundleId {
            return nil
        }
        let pid = nsApp.processIdentifier
        if let existing = allAppsMap[pid] {
            return existing
        } else {
            let app = MacApp(nsApp, AXUIElementCreateApplication(nsApp.processIdentifier))

            if app.observe(refreshObs, kAXWindowCreatedNotification) &&
                app.observe(refreshObs, kAXFocusedWindowChangedNotification)
            {
                allAppsMap[pid] = app
                return app
            } else {
                app.garbageCollect(skipClosedWindowsCache: true)
                return nil
            }
        }
    }

    private func garbageCollect(skipClosedWindowsCache: Bool) {
        MacApp.allAppsMap.removeValue(forKey: nsApp.processIdentifier)
        for obs in axObservers {
            AXObserverRemoveNotification(obs.obs, obs.ax, obs.notif)
        }
        MacWindow.allWindows.lazy.filter { $0.app == self }.forEach { $0.garbageCollect(skipClosedWindowsCache: skipClosedWindowsCache) }
        axObservers = []
    }

    static func garbageCollectTerminatedApps() {
        for app in Array(allAppsMap.values) where app.nsApp.isTerminated {
            app.garbageCollect(skipClosedWindowsCache: true)
        }
    }

    override var name: String? { nsApp.localizedName }

    override var execPath: String? { nsApp.executableURL?.path }

    override var bundlePath: String? { nsApp.bundleURL?.path }

    private func observe(_ handler: AXObserverCallback, _ notifKey: String) -> Bool {
        guard let observer = AXObserver.observe(nsApp.processIdentifier, notifKey, axApp, handler, data: nil) else { return false }
        axObservers.append(AxObserverWrapper(obs: observer, ax: axApp, notif: notifKey as CFString))
        return true
    }

    override func getFocusedWindow(startup: Bool) -> Window? { // todo unused?
        getFocusedAxWindow()?.lets { MacWindow.get(app: self, axWindow: $0, startup: startup) }
    }

    func getFocusedAxWindow() -> AXUIElement? {
        axApp.get(Ax.focusedWindowAttr)
    }

    override func detectNewWindowsAndGetAll(startup: Bool) -> [Window] {
        (axApp.get(Ax.windowsAttr) ?? []).compactMap { MacWindow.get(app: self, axWindow: $0, startup: startup) }
    }
}

extension NSRunningApplication {
    var macApp: MacApp? { MacApp.get(self) }
}
