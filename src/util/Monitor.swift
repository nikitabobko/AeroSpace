struct Monitor: Hashable {
    let name: String?
    let rect: Rect
    let visibleRect: Rect

    static func ==(lhs: Self, rhs: Self) -> Bool { lhs.name == rhs.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

extension NSScreen {
    var monitor: Monitor { Monitor(name: localizedName, rect: rect, visibleRect: visibleRect) }
}
