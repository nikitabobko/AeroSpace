class AeroApp: Hashable {
    let id: Int32

    init(id: Int32) {
        self.id = id
    }

    static func ==(lhs: AeroApp, rhs: AeroApp) -> Bool {
        if lhs.id == rhs.id {
            precondition(lhs === rhs)
            return true
        } else {
            precondition(lhs !== rhs)
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var focusedWindow: Window? { error("Not implemented") }
}
