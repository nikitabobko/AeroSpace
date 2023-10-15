private struct MonitorImpl {
    let name: String
    let rect: Rect
    let visibleRect: Rect
}

extension MonitorImpl: Monitor {
    var height: CGFloat { rect.height }
    var width: CGFloat { rect.width }
}

/// Use it instead of NSScreen for testing purposes
protocol Monitor {
    var name: String { get }
    var rect: Rect { get }
    var visibleRect: Rect { get }
    var width: CGFloat { get }
    var height: CGFloat { get }
}

class LazyMonitor: Monitor {
    private let screen: NSScreen
    let name: String
    let width: CGFloat
    let height: CGFloat
    private var _rect: Rect? = nil
    private var _visibleRect: Rect? = nil

    init(_ screen: NSScreen) {
        self.name = screen.localizedName
        self.width = screen.frame.width // Don't call rect because it would cause recursion during mainMonitor init
        self.height = screen.frame.height // Don't call rect because it would cause recursion during mainMonitor init
        self.screen = screen
    }

    var rect: Rect {
        _rect ?? screen.rect.also { _rect = $0 }
    }

    var visibleRect: Rect {
        _visibleRect ?? screen.visibleRect.also { _visibleRect = $0 }
    }
}

extension NSScreen {
    var monitor: Monitor { MonitorImpl(name: localizedName, rect: rect, visibleRect: visibleRect) }
}
