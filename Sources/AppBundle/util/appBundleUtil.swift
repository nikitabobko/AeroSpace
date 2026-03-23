import AppKit
import Common
import Foundation
import os

let signposter = OSSignposter(subsystem: aeroSpaceAppId, category: .pointsOfInterest)

let myPid = NSRunningApplication.current.processIdentifier
let lockScreenAppBundleId = "com.apple.loginwindow"

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
        await toggleReleaseServerIfDebug(.on)
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
            y: (monitorVisibleRect.height - windowSize.height) / 2,
        )
        try await window.setAxFrameBlocking(point, windowSize)
    }
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
    func distance(toOuterFrame rect: Rect) -> CGFloat {
        // Subtract 1 from maxX/maxY because the right/bottom bounds are
        // exclusive.
        let dx = max(rect.minX - x, 0, x - (rect.maxX - 1))
        let dy = max(rect.minY - y, 0, y - (rect.maxY - 1))
        return CGPoint(x: dx, y: dy).vectorLength
    }

    func coerce(in rect: Rect) -> CGPoint? {
        guard let xRange = rect.minX.until(incl: rect.maxX - 1) else { return nil }
        guard let yRange = rect.minY.until(incl: rect.maxY - 1) else { return nil }
        return CGPoint(x: x.coerce(in: xRange), y: y.coerce(in: yRange))
    }

    func addingXOffset(_ offset: CGFloat) -> CGPoint { CGPoint(x: x + offset, y: y) }
    func addingYOffset(_ offset: CGFloat) -> CGPoint { CGPoint(x: x, y: y + offset) }
    func addingOffset(_ orientation: Orientation, _ offset: CGFloat) -> CGPoint { orientation == .h ? addingXOffset(offset) : addingYOffset(offset) }

    func getProjection(_ orientation: Orientation) -> Double { orientation == .h ? x : y }

    var vectorLength: CGFloat { sqrt(x * x + y * y) }

    var monitorApproximation: Monitor { monitors.minByOrDie { distance(toOuterFrame: $0.rect) } }
}

extension CGFloat {
    func div(_ denominator: Int) -> CGFloat? {
        denominator == 0 ? nil : self / CGFloat(denominator)
    }

    func coerce(in range: ClosedRange<CGFloat>) -> CGFloat {
        switch true {
            case self > range.upperBound: range.upperBound
            case self < range.lowerBound: range.lowerBound
            default: self
        }
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
func checkCancellation() throws(CancellationError) {
    if Task.isCancelled {
        throw CancellationError()
    }
}
