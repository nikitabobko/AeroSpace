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

func activateWindowByName(_ name: String) {
    // Get all running applications
    let runningApps = NSWorkspace.shared.runningApplications

    // Find the first application with a window whose title matches the given name
    let appWithWindow = runningApps.first { app in
        // guard let window = app.windows.first else { return false }
        // return window.title == name
        app.localizedName == name
    }

    // Activate the found application (and bring its window to the front)
    appWithWindow?.activate(options: .activateIgnoringOtherApps)
}

//func activeSpace() {
////    CGSCopyManagedDisplaySpaces(CGSMainConnectionID())?.takeRetainedValue()
////    CGSpacesInfo
////    CGSGetActiveSpace()
//}

//func observeSpaceChanges() {
//    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.spaceChange), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
//}

// NSWorkspace.shared.runningApplications.filter({ $0.activationPolicy == .regular }) also returns garbage
// "Finder virtual desktop window" or something
//func appPidsOnCurrentMacOsSpace() -> [pid_t] {
//    // todo what is excludeDesktopElements?
//    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
//    let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
//    let infoList = windowsListInfo as! [[String:Any]]
//    let windows = infoList.filter { $0["kCGWindowLayer"] as! Int == 0 }
//    return Array(Set(windows.map { $0["kCGWindowOwnerPID"].unsafelyUnwrapped as! pid_t }))
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
