struct Monitor: Hashable {
    let name: String?
    let rect: Rect
    let visibleRect: Rect
}

extension NSScreen {
    var monitor: Monitor {
        Monitor(name: localizedName, rect: rect, visibleRect: visibleRect)
    }
}
