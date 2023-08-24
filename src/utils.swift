import Foundation
import Cocoa
import CoreFoundation
import AppKit

//func activeSpace() {
////    CGSCopyManagedDisplaySpaces(CGSMainConnectionID())?.takeRetainedValue()
////    CGSpacesInfo
////    CGSGetActiveSpace()
//}

//func observeSpaceChanges() {
//    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.spaceChange), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
//}

func windowsOnActiveMacOsSpacesTest() -> [MacWindow] {
    NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .flatMap { $0.macApp.visibleWindowsOnAllMonitors }
}

func test() {
    for screen in NSScreen.screens {
        debug("---")
        debug(screen.localizedName)
        debug(screen.debugDescription)
        debug(screen.visibleRect.topLeftCorner)
        debug(screen.visibleRect)
    }
//    let bar = windowsOnActiveMacOsSpaces().filter { $0.title?.contains("bar") == true }.first!
//    bar.setSize(CGSize(width: monitorWidth, height: monitorHeight))
//    print(bar.getSize())

//    DispatchQueue.main.asyncAfter(deadline: .now()+1) {
//        let windows = windowsOnActiveMacOsSpaces()
//        print(windows.count)
//        let barWindow: Window = windows.filter { $0.title?.contains("Chrome") == true && $0.title?.contains("bar") == true }.first!
//        print(barWindow.getPosition())
//        print("ID: \(barWindow.windowId())")
//    }
}

func stringType(of some: Any) -> String {
//    kAXMinValueAttribute
//    kAXValueAttribute
    let string = (some is Any.Type) ? String(describing: some) : String(describing: type(of: some))
    return string
}

func errorT<T>(_ message: String = "") -> T {
    fatalError(message)
}

func error(_ message: String = "") -> Never {
    fatalError(message)
}

func TODO(_ message: String = "") -> Never {
    fatalError(message)
}

extension NSScreen {
    /// Motivation:
    /// 1. NSScreen.main is a misleading name.
    /// 2. NSScreen.main doesn't work correctly from NSWorkspace.didActivateApplicationNotification &
    ///    kAXFocusedWindowChangedNotification callbacks.
    ///
    /// I hate you Apple
    ///
    /// Returns `nil` if the desktop is selected (which is when the app is active but doesn't show any window)
    static var focusedMonitorOrNilIfDesktop: NSScreen? {
        //NSWorkspace.shared.menuBarOwningApplication?.macApp.focusedWindow?.monitorApproximation
        // todo what's the difference between? NSWorkspace.shared.frontmostApplication

        NSWorkspace.shared.menuBarOwningApplication?.macApp.focusedWindow?.monitorApproximationLowLevel
                ?? NSScreen.screens.singleOrNil()

        //NSWorkspace.shared.menuBarOwningApplication?.macApp.axFocusedWindow?
        //        .get(Ax.topLeftCornerAttr)?.monitorApproximation
        //        ?? NSScreen.screens.singleOrNil()

    }

    var isMainMonitor: Bool {
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

extension CGRect {
    func monitorFrameNormalized() -> Rect {
        let mainMonitorHeight: CGFloat = NSScreen.screens.firstOrThrow { $0.isMainMonitor }.frame.height
        let rect = toRect()
        return rect.copy(topLeftY: mainMonitorHeight - rect.topLeftY)
    }
}

extension CGRect {
    func toRect() -> Rect {
        Rect(topLeftX: minX, topLeftY: maxY, width: width, height: height)
    }
}

struct Rect {
    let topLeftX: CGFloat
    let topLeftY: CGFloat
    let width: CGFloat
    let height: CGFloat
}

extension [Rect] {
    func union() -> Rect {
        let rects: [Rect] = self
        let topLeftY = rects.map { $0.minY }.minOrThrow()
        let topLeftX = rects.map { $0.minX }.maxOrThrow()
        return Rect(
                topLeftX: topLeftX,
                topLeftY: topLeftY,
                width: rects.map { $0.maxX }.maxOrThrow() - topLeftX,
                height: rects.map { $0.maxY}.maxOrThrow() - topLeftY
        )
    }
}

extension Double {
    var squared: Double { self * self }
}

func -(a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x - b.x, y: a.y - b.y)
}

func +(a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x + b.x, y: a.y + b.y)
}

extension CGPoint {
    func copy(x: Double? = nil, y: Double? = nil) -> CGPoint {
        CGPoint(x: x ?? self.x, y: y ?? self.y)
    }

    /// Distance to ``Rect`` outline frame
    func distanceToRectFrame(to rect: Rect) -> CGFloat {
        let list: [CGFloat] = ((rect.minY..<rect.maxY).contains(y) ? [abs(rect.minX - x), abs(rect.maxX - x)] : []) +
                ((rect.minX..<rect.maxX).contains(x) ? [abs(rect.minY - y), abs(rect.maxY - y)] : []) +
                [distance(to: rect.topLeftCorner),
                 distance(to: rect.bottomRightCorner),
                 distance(to: rect.topRightCorner),
                 distance(to: rect.bottomLeftCorner)]
        return list.minOrThrow()
    }

    func distance(to point: CGPoint) -> Double {
        sqrt((x - point.x).squared + (y - point.y).squared)
    }

    var monitorApproximation: NSScreen {
        let pairs: [(monitor: NSScreen, rect: Rect)] = NSScreen.screens.map { ($0, $0.rect) }
        if let pair = pairs.first(where: { $0.rect.contains(self) }) {
            return pair.monitor
        }
        return pairs
                .minByOrThrow { distanceToRectFrame(to: $0.rect) }
                .monitor
    }
}

extension CGSize {
    func copy(width: Double? = nil, height: Double? = nil) -> CGSize {
        CGSize(width: width ?? self.width, height: height ?? self.height)
    }
}

extension Rect {
    func contains(_ point: CGPoint) -> Bool {
        let x = point.x
        let y = point.y
        return (minX..<maxX).contains(x) && (minY..<maxY).contains(y)
    }

    func copy(topLeftX: CGFloat? = nil, topLeftY: CGFloat? = nil, width: CGFloat? = nil, height: CGFloat? = nil) -> Rect {
        Rect(
                topLeftX: topLeftX ?? self.topLeftX,
                topLeftY: topLeftY ?? self.topLeftY,
                width: width ?? self.width,
                height: height ?? self.height
        )
    }

    var topLeftCorner: CGPoint { CGPoint(x: topLeftX, y: topLeftY) }
    var topRightCorner: CGPoint { CGPoint(x: maxX, y: minY) }
    var bottomRightCorner: CGPoint { CGPoint(x: maxX, y: maxY) }
    var bottomLeftCorner: CGPoint { CGPoint(x: minX, y: maxY) }

    var minY: CGFloat { topLeftY }
    var maxY: CGFloat { topLeftY + height }
    var minX: CGFloat { topLeftX }
    var maxX: CGFloat { topLeftX + width }
}

extension Sequence {
    public func filterNotNil<Unwrapped>() -> [Unwrapped] where Element == Unwrapped? {
        compactMap { $0 }
    }

    public func minByOrThrow<S: Comparable>(_ selector: (Self.Element) -> S) -> Self.Element {
        minBy(selector) ?? errorT("Empty sequence")
    }

    public func minBy<S : Comparable>(_ selector: (Self.Element) -> S) -> Self.Element? {
        self.min(by: { a, b in selector(a) < selector(b) })
    }

    public func maxByOrThrow<S : Comparable>(_ selector: (Self.Element) -> S) -> Self.Element? {
        self.maxBy(selector) ?? errorT("Empty sequence")
    }

    public func maxBy<S : Comparable>(_ selector: (Self.Element) -> S) -> Self.Element? {
        self.max(by: { a, b in selector(a) < selector(b) })
    }
}

extension Sequence where Self.Element : Comparable {
    public func minOrThrow() -> Self.Element {
        self.min() ?? errorT("Empty sequence")
    }

    public func maxOrThrow() -> Self.Element {
        self.max() ?? errorT("Empty sequence")
    }
}

extension Array where Self.Element : Equatable {
    @discardableResult
    public mutating func remove(element: Self.Element) -> Bool {
        if let index = firstIndex(of: element) {
            remove(at: index)
            return true
        } else {
            return false
        }
    }
}

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

extension Sequence where Element: Hashable {
    func toSet() -> Set<Element> { Set(self) }
}

extension Array {
    func singleOrNil() -> Element? {
        count == 1 ? first : nil
    }

    func firstOrThrow(where predicate: (Self.Element) throws -> Bool) rethrows -> Self.Element {
        try first(where: predicate) ?? errorT("Can't find the element")
    }
}

func -<T>(lhs: [T], rhs: [T]) -> [T] where T: Hashable {
    let r = rhs.toSet()
    return lhs.filter { !r.contains($0) }
}

extension Set {
    func toArray() -> [Element] { Array(self) }
}

private let DEBUG = true

func debug(_ msg: Any) {
    if DEBUG {
        print(msg)
    }
}
