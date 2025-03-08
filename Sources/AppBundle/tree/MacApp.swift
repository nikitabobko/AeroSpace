import AppKit
import Common

@MainActor
final class MacApp: AbstractApp {
    let nsApp: NSRunningApplication
    let axApp: AXUIElement
    let isZoom: Bool
    let pid: Int32
    let id: String?

    private var axObservers: [AxObserverWrapper] = [] // keep observers in memory

    private init(_ nsApp: NSRunningApplication, _ axApp: AXUIElement) {
        self.nsApp = nsApp
        self.axApp = axApp
        self.isZoom = nsApp.bundleIdentifier == "us.zoom.xos"
        self.pid = nsApp.processIdentifier
        self.id = nsApp.bundleIdentifier
    }

    static var allAppsMap: [pid_t: MacApp] = [:]

    static func get(_ nsApp: NSRunningApplication, mainThread: Bool = true) -> MacApp? {
        if mainThread && nsApp.bundleIdentifier == "com.apple.finder" {
            return nil
        }
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
        MacWindow.allWindows.lazy.filter { $0.app.pid == self.pid }.forEach { $0.garbageCollect(skipClosedWindowsCache: skipClosedWindowsCache) }
        axObservers = []
    }

    static func garbageCollectTerminatedApps() {
        for app in Array(allAppsMap.values) where app.nsApp.isTerminated {
            app.garbageCollect(skipClosedWindowsCache: true)
        }
    }

    nonisolated var name: String? { nsApp.localizedName }

    nonisolated var execPath: String? { nsApp.executableURL?.path }

    nonisolated var bundlePath: String? { nsApp.bundleURL?.path }

    private func observe(_ handler: AXObserverCallback, _ notifKey: String) -> Bool {
        guard let observer = AXObserver.observe(nsApp.processIdentifier, notifKey, axApp, handler, data: nil) else { return false }
        axObservers.append(AxObserverWrapper(obs: observer, ax: axApp, notif: notifKey as CFString))
        return true
    }

    func getFocusedWindow(startup: Bool) -> Window? { // todo unused?
        getFocusedAxWindow()?.lets { MacWindow.get(app: self, axWindow: $0, startup: startup) }
    }

    func getFocusedAxWindow() -> AXUIElement? {
        axApp.get(Ax.focusedWindowAttr)
    }

    func detectNewWindows(startup: Bool) {
        guard let windows = axApp.get(Ax.windowsAttr, signpostEvent: name) else { return }
        for window in windows {
            _ = MacWindow.get(app: self, axWindow: window, startup: startup)
        }
    }
}

extension NSRunningApplication {
    @MainActor
    var macApp: MacApp? { MacApp.get(self) }
}
