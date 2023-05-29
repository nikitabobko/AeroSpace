import Foundation
import Cocoa
import CoreFoundation
import AppKit

// todo compute dynamically later
let monitorWidth = 2560
let monitorHeight = 1440

func detectNewWindows() {
    let currentWorkspace = getWorkspace(name: ViewModel.shared.currentWorkspaceName)
    for newWindow in Set(windowsOnActiveMacOsSpaces()).subtracting(workspaces.values.flatMap { $0.allWindows }) {
        print("New window detected: \(newWindow.title) on workspace \(currentWorkspace.name)")
        currentWorkspace.floatingWindows.append(newWindow)
    }
}

func windowsOnActiveMacOsSpaces() -> [Window] {
    NSWorkspace.shared.runningApplications
            .filter({ $0.activationPolicy == .regular })
            .flatMap({ $0.windowsOnActiveMacOsSpaces })
}

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

extension NSRunningApplication {
    /**
     If there are several monitors then spaces on those monitors will be active
     */
    var windowsOnActiveMacOsSpaces: [Window] {
        let axApp = AXUIElementCreateApplication(processIdentifier)
        return (axApp.get(Ax.windowsAttr) ?? []).compactMap({ Window.get(nsApp: self, axApp: axApp, axWindow: $0) })
    }
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
