import AppKit

final class MacApp: AbstractApp {
    let nsApp: NSRunningApplication
    let axApp: AXUIElement

    private var axObservers: [AxObserverWrapper] = [] // keep observers in memory

    private init(_ nsApp: NSRunningApplication, _ axApp: AXUIElement) {
        self.nsApp = nsApp
        self.axApp = axApp
        super.init(pid: nsApp.processIdentifier, id: nsApp.bundleIdentifier)
    }

    private static var allAppsMap: [pid_t: MacApp] = [:]

    fileprivate static func get(_ nsApp: NSRunningApplication) -> MacApp? {
        let pid = nsApp.processIdentifier
        if let existing = allAppsMap[pid] {
            return existing
        } else {
            let app = MacApp(nsApp, AXUIElementCreateApplication(nsApp.processIdentifier))

            if app.observe(refreshObs, kAXWindowCreatedNotification) &&
                    app.observe(refreshObs, kAXFocusedWindowChangedNotification) {
                allAppsMap[pid] = app
                return app
            } else {
                app.garbageCollect()
                return nil
            }
        }
    }

    private func garbageCollect() {
        debug("garbageCollectApp: terminated \(self.name ?? "")")
        MacApp.allAppsMap.removeValue(forKey: nsApp.processIdentifier)
        for obs in axObservers {
            AXObserverRemoveNotification(obs.obs, obs.ax, obs.notif)
        }
        MacWindow.allWindows.lazy.filter { $0.app == self }.forEach { $0.garbageCollect() }
        axObservers = []
    }

    static func garbageCollectTerminatedApps() {
        for app in Array(allAppsMap.values) where app.nsApp.isTerminated {
            app.garbageCollect()
        }
    }

    override var name: String? { nsApp.localizedName }

    private func observe(_ handler: AXObserverCallback, _ notifKey: String) -> Bool {
        guard let observer = AXObserver.observe(nsApp.processIdentifier, notifKey, axApp, handler, data: nil) else { return false }
        axObservers.append(AxObserverWrapper(obs: observer, ax: axApp, notif: notifKey as CFString))
        return true
    }

    override func getFocusedWindow(startup: Bool) -> Window? {
        getFocusedAxWindow()?.lets { MacWindow.get(app: self, axWindow: $0, startup: startup) }
    }

    func getFocusedAxWindow() -> AXUIElement? {
        axApp.get(Ax.focusedWindowAttr)
    }

    override func detectNewWindowsAndGetAll(startup: Bool) -> [Window] {
        (axApp.get(Ax.windowsAttr) ?? []).compactMap({ MacWindow.get(app: self, axWindow: $0, startup: startup) })
    }
}

extension NSRunningApplication {
    var macApp: MacApp? { MacApp.get(self) }
}
