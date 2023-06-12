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
        debug(screen.visibleFrame.origin)
        debug("minX: \(screen.visibleFrame.minX)")
        debug("width: \(screen.visibleFrame.width)")
        debug(screen.visibleFrame)
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

extension NSScreen {
    var isMainMonitor: Bool {
        visibleFrame.minX == 0 && visibleFrame.minY == 0
    }
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
     */
    static var focusedMonitor: NSScreen? {
        guard let app = NSWorkspace.shared.frontmostApplication?.macApp else { return nil }
        let focusedWindow = app.focusedWindow
        // Desktop is in focus. We can do nothing to get current focused monitor reliably (well, I didn't manage to)
        if app.isFinder && focusedWindow == nil {
            return nil
        }
        return focusedWindow?.monitor
    }
}

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }

    // todo unused?
    var monitor: NSScreen? {
        NSScreen.screens.first { $0.frame.contains(self) }
    }
}

extension Sequence where Element: Hashable {
    func toSet() -> Set<Element> { Set(self) }
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
