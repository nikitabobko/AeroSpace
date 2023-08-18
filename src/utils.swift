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

extension NSScreen {
    /**
     Because:
     1. NSScreen.main is a misleading name.
     2. NSScreen.main doesn't work correctly from NSWorkspace.didActivateApplicationNotification &
        kAXFocusedWindowChangedNotification callbacks.

     I hate you Apple

     Returns `nil` if the desktop is selected (which is Finder special window)
     */
    static var focusedMonitorOrNilIfDesktop: NSScreen? {
        NSWorkspace.shared.menuBarOwningApplication?.macApp.focusedWindow?.monitor ?? NSScreen.screens.singleOrNil()
    }

    var isMainMonitor: Bool {
        frame.minX == 0 && frame.minY == 0
    }

    /// This property normalizes crazy Apple API
    /// ``NSScreen.frame`` assumes that main screen bottom left corner is (0, 0) and positive y-axis goes up.
    /// But for windows it's top left corner and y-axis goes down
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

    func copy(topLeftX: CGFloat? = nil, topLeftY: CGFloat? = nil, width: CGFloat? = nil, height: CGFloat? = nil) -> Rect {
        Rect(
                topLeftX: topLeftX ?? self.topLeftX,
                topLeftY: topLeftY ?? self.topLeftY,
                width: width ?? self.width,
                height: height ?? self.height
        )
    }
}

extension Rect {
    func contains(_ point: CGPoint) -> Bool {
        let x = point.x
        let y = point.y
        return x >= topLeftX && x <= topLeftX + width && y >= topLeftY && y <= topLeftY + height
    }

    var topLeft: CGPoint {
        CGPoint(x: topLeftX, y: topLeftY)
    }

    var bottomRight: CGPoint {
        CGPoint(x: topLeftX + width, y: topLeftY + height)
    }
}

extension Sequence {
    public func filterNotNil<Unwrapped>() -> [Unwrapped] where Element == Unwrapped? {
        compactMap { $0 }
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
