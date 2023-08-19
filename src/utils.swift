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
            .flatMap { $0.macApp.windowsOnActiveMacOsSpaces }
}

func test() {
    for screen in NSScreen.screens {
        debug("---")
        debug(screen.localizedName)
        debug(screen.debugDescription)
        debug(screen.visibleRect.topLeft)
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
    /// Because:
    /// 1. NSScreen.main is a misleading name.
    /// 2. NSScreen.main doesn't work correctly from NSWorkspace.didActivateApplicationNotification &
    ///    kAXFocusedWindowChangedNotification callbacks.
    ///
    /// I hate you Apple
    ///
    /// Returns `nil` if the desktop is selected (which is Finder special window)
    static var focusedMonitorOrNilIfDesktop: NSScreen? {
        NSWorkspace.shared.menuBarOwningApplication?.macApp.focusedWindow?.monitorApproximation ?? NSScreen.screens.singleOrNil()
    }

    var isMainMonitor: Bool {
        frame.minX == 0 && frame.minY == 0
    }

    /// This property normalizes crazy Apple API
    /// ``NSScreen.frame`` assumes that main screen bottom left corner is (0, 0) and positive y-axis goes up.
    /// But for windows it's top left corner and positive y-axis goes down
    var rect: Rect {
        let mainMonitorHeight: CGFloat = NSScreen.screens.firstOrThrow { $0.isMainMonitor }.frame.height
        let rect = frame.toRect()
        return rect.copy(topLeftY: mainMonitorHeight - rect.topLeftY)
    }

    var visibleRect: Rect {
        let mainMonitorHeight: CGFloat = NSScreen.screens.firstOrThrow { $0.isMainMonitor }.frame.height
        let rect = visibleFrame.toRect()
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

struct Pair<F, S> {
    let first: F
    let second: S
}

extension Double {
    var squared: Double { self * self }
}

extension CGPoint {
    func copy(x: Double? = nil, y: Double? = nil) -> CGPoint {
        CGPoint(x: x ?? self.x, y: y ?? self.y)
    }

    /// Distance to ``Rect`` outline frame
    func distanceToRectFrame(to rect: Rect) -> CGFloat {
        let list: [CGFloat] = ((rect.minY..<rect.maxY).contains(y) ? [abs(rect.minX - x), abs(rect.maxX - x)] : []) +
                ((rect.minX..<rect.maxX).contains(x) ? [abs(rect.minY - y), abs(rect.maxY - y)] : []) +
                [distance(to: rect.topLeft),
                 distance(to: rect.bottomRight),
                 distance(to: rect.topRight),
                 distance(to: rect.bottomLeft)]
        return list.minOrThrow()
    }

    func distance(to point: CGPoint) -> Double {
        sqrt((x - point.x).squared + (y - point.y).squared)
    }

    var monitorApproximation: NSScreen {
        let monitors: [Pair<NSScreen, Rect>] = NSScreen.screens.map { Pair(first: $0, second: $0.rect) }
        if let monitor = monitors.first(where: { $0.second.contains(self) }) {
            return monitor.first
        }
        return monitors
                .minOrThrow(by: { a, b in distanceToRectFrame(to: a.second) < distanceToRectFrame(to: b.second) })
                .first
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

    var topLeft: CGPoint { CGPoint(x: topLeftX, y: topLeftY) }
    var topRight: CGPoint { CGPoint(x: maxX, y: minY) }
    var bottomRight: CGPoint { CGPoint(x: maxX, y: maxY) }
    var bottomLeft: CGPoint { CGPoint(x: minX, y: maxY) }

    var minY: CGFloat { topLeftY }
    var maxY: CGFloat { topLeftY + height }
    var minX: CGFloat { topLeftX }
    var maxX: CGFloat { topLeftX + width }
}

extension Sequence {
    public func filterNotNil<Unwrapped>() -> [Unwrapped] where Element == Unwrapped? {
        compactMap { $0 }
    }

    public func minOrThrow(by: (Self.Element, Self.Element) throws -> Bool) rethrows -> Self.Element {
        try self.min(by: by) ?? errorT("Empty sequence")
    }
}

extension Sequence where Self.Element : Comparable {
    public func minOrThrow() -> Self.Element {
        self.min() ?? errorT("Empty sequence")
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

extension Set {
    // todo unused?
    func toArray() -> [Element] { Array(self) }
}

private let DEBUG = true

func debug(_ msg: Any) {
    if DEBUG {
        print(msg)
    }
}
