private struct MonitorImpl {
    let name: String
    let rect: Rect
    let visibleRect: Rect
}

extension MonitorImpl: Monitor {
    var height: CGFloat { rect.height }
    var width: CGFloat { rect.width }
}

/// Use it instead of NSScreen because it can be mocked in tests
protocol Monitor: AeroAny {
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

private extension NSScreen {
    var monitor: Monitor { MonitorImpl(name: localizedName, rect: rect, visibleRect: visibleRect) }

    var isMainScreen: Bool {
        frame.minX == 0 && frame.minY == 0
    }

    /// The property is a replacement for Apple's crazy ``frame``
    ///
    /// - For ``MacWindow.topLeftCorner``, (0, 0) is main screen top left corner, and positive y-axis goes down.
    /// - For ``frame``, (0, 0) is main screen bottom left corner, and positive y-axis goes up (which is crazy).
    ///
    /// The property "normalizes" ``frame``
    var rect: Rect { frame.monitorFrameNormalized() }

    /// Same as ``rect`` but for ``visibleFrame``
    var visibleRect: Rect { visibleFrame.monitorFrameNormalized() }
}

private let testMonitorRect = Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080)
private let testMonitor = MonitorImpl(name: "Test Monitor", rect: testMonitorRect, visibleRect: testMonitorRect)

/// Motivation:
/// 1. NSScreen.main is a misleading name.
/// 2. NSScreen.main doesn't work correctly from NSWorkspace.didActivateApplicationNotification &
///    kAXFocusedWindowChangedNotification callbacks.
///
/// Returns `nil` if the desktop is selected (which is when the app is active but doesn't show any window)
var focusedMonitorOrNilIfDesktop: Monitor? {
    isUnitTest ? testMonitor : (focusedWindow?.getCenter()?.monitorApproximation ?? monitors.singleOrNil())
    //NSWorkspace.activeApp?.macApp?.axFocusedWindow?
    //        .get(Ax.topLeftCornerAttr)?.monitorApproximation
    //        ?? NSScreen.screens.singleOrNil()
}

/// It's inaccurate because NSScreen.main doesn't work correctly from NSWorkspace.didActivateApplicationNotification &
/// kAXFocusedWindowChangedNotification callbacks.
var focusedMonitorInaccurate: Monitor? {
    isUnitTest ? testMonitor : NSScreen.main?.monitor
}

var mainMonitor: Monitor {
    isUnitTest ? testMonitor : LazyMonitor(NSScreen.screens.singleOrNil(where: \.isMainScreen)!)
}

var monitors: [Monitor] { isUnitTest ? [testMonitor] : NSScreen.screens.map(\.monitor) }

var sortedMonitors: [Monitor] {
    monitors.sorted(using: [SelectorComparator(selector: \.rect.minX), SelectorComparator(selector: \.rect.minY)])
}
