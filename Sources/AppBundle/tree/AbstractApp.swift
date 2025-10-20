import Common

protocol AbstractApp: AnyObject, Hashable, AeroAny {
    var pid: Int32 { get }
    var rawAppBundleId: String? { get }

    @MainActor func getFocusedWindow() async throws -> Window?
    var name: String? { get }
    var execPath: String? { get }
    var bundlePath: String? { get }
}

extension AbstractApp {
    static func == (lhs: Self, rhs: Self) -> Bool {
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
}

extension Window {
    var macAppUnsafe: MacApp { app as! MacApp }
}
