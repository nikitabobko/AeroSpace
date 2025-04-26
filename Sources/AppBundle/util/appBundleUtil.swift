import AppKit
import Common
import Foundation
import os

let signposter = OSSignposter(subsystem: aeroSpaceAppId, category: .pointsOfInterest)

let lockScreenAppBundleId = "com.apple.loginwindow"
let AEROSPACE_WINDOW_ID = "AEROSPACE_WINDOW_ID" // env var
let AEROSPACE_WORKSPACE = "AEROSPACE_WORKSPACE" // env var

func stringType(of some: Any) -> String {
    let string = (some is Any.Type) ? String(describing: some) : String(describing: type(of: some))
    return string
}

func interceptTermination(_ _signal: Int32) {
    signal(_signal, { signal in
        check(Thread.current.isMainThread)
        Task {
            defer { exit(signal) }
            try await terminationHandler.beforeTermination()
        }
    } as sig_t)
}

@MainActor
func initTerminationHandler() {
    terminationHandler = AppServerTerminationHandler()
}

private struct AppServerTerminationHandler: TerminationHandler {
    func beforeTermination() async throws {
        try await makeAllWindowsVisibleAndRestoreSize()
        if isDebug {
            sendCommandToReleaseServer(args: ["enable", "on"])
        }
    }
}

@MainActor
private func makeAllWindowsVisibleAndRestoreSize() async throws {
    // Make all windows fullscreen before Quit
    for (_, window) in MacWindow.allWindowsMap {
        // makeAllWindowsVisibleAndRestoreSize may be invoked when something went wrong (e.g. some windows are unbound)
        // that's why it's not allowed to use `.parent` call in here
        let monitor = try await window.getCenter()?.monitorApproximation ?? mainMonitor
        let monitorVisibleRect = monitor.visibleRect
        let windowSize = window.lastFloatingSize ?? CGSize(width: monitorVisibleRect.width, height: monitorVisibleRect.height)
        let point = CGPoint(
            x: (monitorVisibleRect.width - windowSize.width) / 2,
            y: (monitorVisibleRect.height - windowSize.height) / 2
        )
        try await window.setAxFrameBlocking(point, windowSize)
    }
}

extension String? {
    var isNilOrEmpty: Bool { self == nil || self?.isEmpty == true }
}

@MainActor
func terminateApp() -> Never {
    NSApplication.shared.terminate(nil)
    die("Unreachable code")
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

extension CGPoint: ConvenienceCopyable {}

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
        return list.minOrDie()
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
            ?? monitors.minByOrDie { distanceToRectFrame(to: $0.rect) }
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

extension CGPoint: @retroactive Hashable { // todo migrate to self written Point
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

#if DEBUG
    let isDebug = true
#else
    let isDebug = false
#endif

@inlinable
public func checkCancellation() throws(CancellationError) {
    if Task.isCancelled {
        throw CancellationError()
    }
}
