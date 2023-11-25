class AeroApp: Hashable {
    let pid: Int32
    let id: String?

    init(pid: Int32, id: String?) {
        self.pid = pid
        self.id = id
    }

    static func ==(lhs: AeroApp, rhs: AeroApp) -> Bool {
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

    func getFocusedWindow(startup: Bool) -> Window? { error("Not implemented") }
    var name: String? { nil }
    func detectNewWindowsAndGetAll(startup: Bool) -> [Window] { error("Not implemented") }
}
