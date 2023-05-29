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

func test() {
    for screen in NSScreen.screens {
        print("---")
        print(screen.localizedName)
        print(screen.debugDescription)
        print(screen.visibleFrame.origin)
        print("minX: \(screen.visibleFrame.minX)")
        print("width: \(screen.visibleFrame.width)")
        print(screen.visibleFrame)
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
     Because "main" is a misleading name
     */
    static var focusedMonitor: NSScreen? { main }
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

extension Set {
    // todo unused?
    func toArray() -> [Element] { Array(self) }
}
