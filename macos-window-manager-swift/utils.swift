import Foundation
import Cocoa
import CoreFoundation
import AppKit

// todo compute dynamically later
let monitorWidth = 2560
let monitorHeight = 1440

func accessibilityPermissions() {
    let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
    if !AXIsProcessTrustedWithOptions(options as CFDictionary) {
        fatalError("untrusted")
    }
}

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

/// - doesn't return minimized windows
/// - returns hidden windows
func allWindowsOnCurrentMacOsSpace() {
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
    let infoList = windowsListInfo as! [[String:Any]]
    let windows = infoList.filter { $0["kCGWindowLayer"] as! Int == 0 }
    print(windows.count)
    for window in windows {
        print(window)
        print("Name: \(window["kCGWindowOwnerName"].unsafelyUnwrapped)")
        print("PID: \(window["kCGWindowOwnerPID"].unsafelyUnwrapped)")
        print("window ID: \(window["kCGWindowNumber"])")
        print("---")
    }
}

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
    DispatchQueue.main.asyncAfter(deadline: .now()+1) {
        let windows = windowsOnActiveMacOsSpaces()
        print(windows.count)
        let barWindow: Window = windows.filter { $0.title?.contains("Chrome") == true && $0.title?.contains("bar") == true }.first!
        print(barWindow.getPosition())
        print("ID: \(barWindow.windowId())")
    }
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

protocol ReadableAttr {
    associatedtype T
    var getter: (AnyObject) -> T { get }
    var value: String { get }
}

protocol WritableAttr : ReadableAttr {
    var setter: (T) -> CFTypeRef { get }
}

enum Ax {
    struct ReadableAttrImpl<T>: ReadableAttr {
        var value: String
        var getter: (AnyObject) -> T
    }

    struct WritableAttrImpl<T>: WritableAttr {
        var value: String
        var getter: (AnyObject) -> T
        var setter: (T) -> CFTypeRef
    }

    // todo wip
    static let valueAttr = ReadableAttrImpl<String>(
            value: kAXValueAttribute,
            getter: { foo in
                print(stringType(of: foo))
                return ""
            }
    )
    static let titleAttr = WritableAttrImpl<String>(
            value: kAXTitleAttribute,
            getter: { $0 as! String },
            setter: { $0 as CFTypeRef }
    )
    static let sizeAttr = WritableAttrImpl<CGSize>(
            value: kAXSizeAttribute,
            getter: {
                var raw: CGSize = .zero
                assert(AXValueGetValue($0 as! AXValue, .cgSize, &raw))
                return raw
            },
            setter: {
                var size = $0
                return AXValueCreate(.cgSize, &size) as CFTypeRef
            }
    )
    static let positionAttr = WritableAttrImpl<CGPoint>(
            value: kAXPositionAttribute,
            getter: {
                var raw: CGPoint = .zero
                AXValueGetValue($0 as! AXValue, .cgPoint, &raw)
                return raw
            },
            setter: {
                var size = $0
                return AXValueCreate(.cgPoint, &size) as CFTypeRef
            }
    )
    static let windowsAttr = ReadableAttrImpl<[AXUIElement]>(
            value: kAXWindowsAttribute,
            getter: { ($0 as! NSArray).compactMap { $0 as! AXUIElement } }
    )
    // todo unused?
    static let focusedWindowAttr = ReadableAttrImpl<AXUIElement>(
            value: kAXFocusedWindowAttribute,
            getter: { $0 as! AXUIElement }
    )
    static let closeButtonAttr = ReadableAttrImpl<AXUIElement>(
            value: kAXCloseButtonAttribute,
            getter: { $0 as! AXUIElement }
    )
}

extension AXUIElement {
    func get<Attr: ReadableAttr>(_ attr: Attr) -> Attr.T? {
        var raw: AnyObject?
        return AXUIElementCopyAttributeValue(self, attr.value as CFString, &raw) == .success
                ? attr.getter(raw!)
                : nil
    }

    func set<Attr: WritableAttr>(_ attr: Attr, _ value: Attr.T) -> Bool {
        AXUIElementSetAttributeValue(self, attr.value as CFString, attr.setter(value)) == .success
    }

    func windowId() -> CGWindowID? {
        var cgWindowId = CGWindowID()
        return _AXUIElementGetWindow(self, &cgWindowId) == .success ? cgWindowId : nil
    }
}
