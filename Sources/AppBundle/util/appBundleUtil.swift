import AppKit
import Common
import Foundation

let AEROSPACE_WINDOW_ID = "AEROSPACE_WINDOW_ID" // env var
let AEROSPACE_WORKSPACE = "AEROSPACE_WORKSPACE" // env var

func stringType(of some: Any) -> String {
    let string = (some is Any.Type) ? String(describing: some) : String(describing: type(of: some))
    return string
}

func interceptTermination(_ _signal: Int32) {
    signal(_signal, { signal in
        check(Thread.current.isMainThread)
        terminationHandler.beforeTermination()
        exit(signal)
    } as sig_t)
}

func initTerminationHandler() {
    terminationHandler = AppServerTerminationHandler()
}

private struct AppServerTerminationHandler: TerminationHandler {
    func beforeTermination() {
        makeAllWindowsVisibleAndRestoreSize()
        if isDebug {
            sendCommandToReleaseServer(args: ["enable", "on"])
        }
    }
}

private func makeAllWindowsVisibleAndRestoreSize() {
    for app in apps { // Make all windows fullscreen before Quit
        for window in app.detectNewWindowsAndGetAll(startup: false) {
            // makeAllWindowsVisibleAndRestoreSize may be invoked when something went wrong (e.g. some windows are unbound)
            // that's why it's not allowed to use `.parent` call in here
            let monitor = window.getCenter()?.monitorApproximation ?? mainMonitor
            let monitorVisibleRect = monitor.visibleRect
            let windowSize = window.lastFloatingSize ?? CGSize(width: monitorVisibleRect.width, height: monitorVisibleRect.height)
            let point = CGPoint(
                x: (monitorVisibleRect.width - windowSize.width) / 2,
                y: (monitorVisibleRect.height - windowSize.height) / 2
            )
            _ = window.setFrame(point, windowSize)
        }
    }
}

extension String? {
    var isNilOrEmpty: Bool { self == nil || self?.isEmpty == true }
}

var apps: [AbstractApp] {
    isUnitTest
        ? appForTests.asList()
        : NSWorkspace.shared.runningApplications.lazy.filter { $0.activationPolicy == .regular }.map(\.macApp).filterNotNil()
}

func terminateApp() -> Never {
    NSApplication.shared.terminate(nil)
    error("Unreachable code")
}

extension String {
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(self, forType: .string)
    }
}

func - (a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x - b.x, y: a.y - b.y)
}

func + (a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x + b.x, y: a.y + b.y)
}

extension CGPoint: Copyable {}

extension CGPoint {
    /// Distance to ``Rect`` outline frame
    func distanceToRectFrame(to rect: Rect) -> CGFloat {
        let list: [CGFloat] = ((rect.minY ..< rect.maxY).contains(y) ? [abs(rect.minX - x), abs(rect.maxX - x)] : []) +
            ((rect.minX ..< rect.maxX).contains(x) ? [abs(rect.minY - y), abs(rect.maxY - y)] : []) +
            [
                distance(to: rect.topLeftCorner),
                distance(to: rect.bottomRightCorner),
                distance(to: rect.topRightCorner),
                distance(to: rect.bottomLeftCorner),
            ]
        return list.minOrThrow()
    }

    func coerceIn(rect: Rect) -> CGPoint {
        CGPoint(x: x.coerceIn(rect.minX ... (rect.maxX - 1)), y: y.coerceIn(rect.minY ... (rect.maxY - 1)))
    }

    func addingXOffset(_ offset: CGFloat) -> CGPoint { CGPoint(x: x + offset, y: y) }
    func addingYOffset(_ offset: CGFloat) -> CGPoint { CGPoint(x: x, y: y + offset) }
    func addingOffset(_ orientation: Orientation, _ offset: CGFloat) -> CGPoint { orientation == .h ? addingXOffset(offset) : addingYOffset(offset) }

    func getProjection(_ orientation: Orientation) -> Double { orientation == .h ? x : y }

    var vectorLength: CGFloat { sqrt(x * x - y * y) }

    func distance(to point: CGPoint) -> Double {
        sqrt((x - point.x).squared + (y - point.y).squared)
    }

    var monitorApproximation: Monitor {
        let monitors = monitors
        return monitors.first(where: { $0.rect.contains(self) })
            ?? monitors.minByOrThrow { distanceToRectFrame(to: $0.rect) }
    }
}

extension CGFloat {
    func div(_ denominator: Int) -> CGFloat? {
        denominator == 0 ? nil : self / CGFloat(denominator)
    }

    func coerceIn(_ range: ClosedRange<CGFloat>) -> CGFloat {
        switch () {
            case _ where self > range.upperBound: range.upperBound
            case _ where self < range.lowerBound: range.lowerBound
            default: self
        }
    }
}

extension CGSize {
    func copy(width: Double? = nil, height: Double? = nil) -> CGSize {
        CGSize(width: width ?? self.width, height: height ?? self.height)
    }
}

extension CGPoint: Swift.Hashable { // todo migrate to self written Point
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

extension Set {
    func toArray() -> [Element] { Array(self) }
}

#if DEBUG
    let isDebug = true
#else
    let isDebug = false
#endif
