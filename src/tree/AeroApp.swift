class AeroApp: Hashable {
    let id: Int32

    init(id: Int32) {
        self.id = id
    }

    static func ==(lhs: AeroApp, rhs: AeroApp) -> Bool {
        if lhs.id == rhs.id {
            check(lhs === rhs)
            return true
        } else {
            check(lhs !== rhs)
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var title: String? { nil }
    var focusedWindow: Window? { error("Not implemented") }
    var windows: [Window] { error("Not implemented") }
}
