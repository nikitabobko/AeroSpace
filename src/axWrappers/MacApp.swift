import Foundation

class MacApp: Hashable {
    let nsApp: NSRunningApplication
    private let axApp: AXUIElement

    private var axObservers: [AxObserverWrapper] = [] // keep observers in memory

    private init(_ nsApp: NSRunningApplication, _ axApp: AXUIElement) {
        self.nsApp = nsApp
        self.axApp = axApp
    }

    private static var apps: [pid_t: MacApp] = [:]

    fileprivate static func get(_ nsApp: NSRunningApplication) -> MacApp {
        let pid = nsApp.processIdentifier
        if let existing = apps[pid] {
            return existing
        } else {
            let app = MacApp(nsApp, AXUIElementCreateApplication(nsApp.processIdentifier))

            app.observe(refreshObs, kAXWindowCreatedNotification)
            app.observe(refreshObs, kAXFocusedWindowChangedNotification)

            apps[pid] = app
            return app
        }
    }

    static func garbageCollectTerminatedApps() {
        apps = apps.filter { pid, app in
            let isTerminated = app.nsApp.isTerminated
            if isTerminated {
                debug("terminated \(app.title ?? "")")
            }
            return !isTerminated
        }
    }

    var title: String? { nsApp.localizedName }

    private func observe(_ handler: AXObserverCallback, _ notifKey: String) {
        guard let observer = AXObserver.observe(nsApp.processIdentifier, notifKey, axApp, data: nil, handler) else { return }
        axObservers.append(AxObserverWrapper(obs: observer, ax: axApp, notif: notifKey as CFString))
    }

    static func ==(lhs: MacApp, rhs: MacApp) -> Bool {
        lhs.nsApp.processIdentifier == rhs.nsApp.processIdentifier
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
}

extension NSRunningApplication {
    var macApp: MacApp { MacApp.get(self) }
}

extension MacApp {
    var visibleWindowsOnAllMonitors: [MacWindow] {
        (axApp.get(Ax.windowsAttr) ?? []).compactMap({ MacWindow.get(app: self, axWindow: $0) })
    }
}
