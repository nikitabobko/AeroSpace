import Foundation

class MacApp: Hashable { // todo rename to App?
    let nsApp: NSRunningApplication
    // todo: make private
    let axApp: AXUIElement

    // todo cleanup resource
    private var axObservers: [AXObserverWrapper] = [] // keep observers in memory

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

            // todo subscribe on app destroy

            apps[pid] = app
            return app
        }
    }

    var title: String? { nsApp.localizedName }

    private func observe(_ handler: AXObserverCallback, _ notifKey: String) {
        let observer = AXObserver.observe(nsApp.processIdentifier, notifKey, axApp, self, handler)
        axObservers.append(AXObserverWrapper(obs: observer, ax: axApp, notif: notifKey as CFString))
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

// todo unused
private extension UnsafeMutableRawPointer {
    var app: MacApp { Unmanaged.fromOpaque(self).takeRetainedValue() }
}

extension MacApp {
    /// If there are several monitors then spaces on those monitors will be active
    var windowsOnActiveMacOsSpaces: [MacWindow] {
        (axApp.get(Ax.windowsAttr) ?? []).compactMap({ MacWindow.get(app: self, axWindow: $0) })
    }
}
