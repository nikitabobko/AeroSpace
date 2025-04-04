import Common

class AbstractApp: Hashable {
    let pid: Int32
    let id: String?

    init(pid: Int32, id: String?) {
        self.pid = pid
        self.id = id
    }

    static func == (lhs: AbstractApp, rhs: AbstractApp) -> Bool {
        if lhs.pid == rhs.pid {
            check(lhs === rhs)
            return true
        } else {
            check(lhs !== rhs)
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
    }

    @MainActor func getFocusedWindow(startup: Bool) -> Window? { error("Not implemented") }
    var name: String? { nil }
    var execPath: String? { nil }
    var bundlePath: String? { nil }
    @MainActor func detectNewWindows(startup: Bool) { error("Not implemented") }
}

extension AbstractApp {
    func asMacApp() -> MacApp { self as! MacApp }

    func isFirefox() -> Bool {
        ["org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly"].contains(id ?? "")
    }
}

extension Window {
    var macAppUnsafe: MacApp { app.asMacApp() }
}
