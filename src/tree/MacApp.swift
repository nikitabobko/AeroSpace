import Foundation

class MacApp: Hashable {
    let nsApp: NSRunningApplication
    private let axApp: AXUIElement

    private var axObservers: [AxObserverWrapper] = [] // keep observers in memory

    private init(_ nsApp: NSRunningApplication, _ axApp: AXUIElement) {
        self.nsApp = nsApp
        self.axApp = axApp
    }

    private static var allApps: [pid_t: MacApp] = [:]

    fileprivate static func get(_ nsApp: NSRunningApplication) -> MacApp? {
        let pid = nsApp.processIdentifier
        if let existing = allApps[pid] {
            return existing
        } else {
            let app = MacApp(nsApp, AXUIElementCreateApplication(nsApp.processIdentifier))

            if app.observe(refreshObs, kAXWindowCreatedNotification) &&
                       app.observe(refreshObs, kAXFocusedWindowChangedNotification) {
                allApps[pid] = app
                return app
            } else {
                app.garbageCollect()
                return nil
            }
        }
    }

    private func garbageCollect() {
        debug("garbageCollectApp: terminated \(self.title ?? "")")
        MacApp.allApps.removeValue(forKey: nsApp.processIdentifier)
        for obs in axObservers {
            AXObserverRemoveNotification(obs.obs, obs.ax, obs.notif)
        }
        MacWindow.allWindows.lazy.filter { $0.app == self }.forEach { $0.garbageCollect() }
        axObservers = []
    }

    static func garbageCollectTerminatedApps() {
        for app in Array(allApps.values) {
            if app.nsApp.isTerminated {
                app.garbageCollect()
            }
        }
    }

    var title: String? { nsApp.localizedName }

    private func observe(_ handler: AXObserverCallback, _ notifKey: String) -> Bool {
        guard let observer = AXObserver.observe(nsApp.processIdentifier, notifKey, axApp, handler) else { return false }
        axObservers.append(AxObserverWrapper(obs: observer, ax: axApp, notif: notifKey as CFString))
        return true
    }

    static func ==(lhs: MacApp, rhs: MacApp) -> Bool {
        if lhs.nsApp.processIdentifier == rhs.nsApp.processIdentifier {
            precondition(lhs === rhs)
            return true
        } else {
            precondition(lhs !== rhs)
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(nsApp.processIdentifier)
    }

    var focusedWindow: MacWindow? {
        axFocusedWindow.flatMap { MacWindow.get(app: self, axWindow: $0) }
    }

    var axFocusedWindow: AXUIElement? {
        axApp.get(Ax.focusedWindowAttr)
    }

    var windows: [MacWindow] {
        (axApp.get(Ax.windowsAttr) ?? []).compactMap({ MacWindow.get(app: self, axWindow: $0) })
    }
}

extension NSRunningApplication {
    var macApp: MacApp? { MacApp.get(self) }
}
