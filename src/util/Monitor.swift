import Foundation

struct Monitor {
    let name: String?
    let rect: Rect
}

extension NSScreen {
    var monitor: Monitor {
        Monitor(name: localizedName, rect: rect)
    }
}
