import Foundation
import Cocoa
import CoreFoundation
import AppKit

// todo compute dynamically later
let monitorWidth = 1800
let monitorHeight = 1125

func accessibilityPermissions() {
    let options = [
        kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
    ]
    AXIsProcessTrustedWithOptions(options as CFDictionary)
    if !AXIsProcessTrusted() {
        print("untrusted")
        exit(1)
    }
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

func windows() {
    let windows: [Window] = NSWorkspace.shared.runningApplications
            .filter({ $0.activationPolicy == .regular })
            .flatMap({ $0.windows })
    print(windows.count)
    for window in windows {
        print("---")
        print(window.title)
        print(window.isHidden)
        if window.title?.contains("macos") == true {
//            window.setSize(CGSize(width: 300, height: 200))
            window.setPosition(CGPoint(x: 0, y: 0))
        }
    }
}

extension NSRunningApplication {
    var windows: [Window] {
        (AXUIElement.from(processIdentifier, Ax.windowsAttr) ?? [])
                .map({ Window(nsApp: self, axWindow: $0) })
    }
}

func stringType(of some: Any) -> String {
    let string = (some is Any.Type) ? String(describing: some) : String(describing: type(of: some))
    return string
}

//protocol AttrP {
//    associatedtype T
//    func convert(any: AnyObject) -> T
//}

enum Ax {
    struct Attr<T> {
        let value: String
        let getter: (AnyObject) -> T
        let setter: (T) -> CFTypeRef
    }

    static let titleAttr = Attr<String>(
            value: kAXTitleAttribute,
            getter: { $0 as! String },
            setter: { $0 as CFTypeRef }
    )
    static let sizeAttr = Attr<CGSize>(
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
    static let positionAttr = Attr<CGPoint>(
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
    static let windowsAttr = Attr<[AXUIElement]>(
            value: kAXWindowsAttribute,
            getter: { ($0 as! NSArray).compactMap { $0 as! AXUIElement } },
            setter: { _ in fatalError("WTF") } // todo
    )
}

extension AXUIElement {
    // todo narrow down to windows attr?
    static func from<T>(_ pid: pid_t, _ attr: Ax.Attr<T>) -> T? {
        var raw: AnyObject?
        if (AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), attr.value as CFString, &raw) == .success) {
            return attr.getter(raw!)
        } else {
            return nil
        }
    }

    func get<T>(_ attr: Ax.Attr<T>) -> T? {
        var raw: AnyObject?
        if (AXUIElementCopyAttributeValue(self, attr.value as CFString, &raw) == .success) {
            return attr.getter(raw!)
        } else {
            return nil
        }
    }

    func set<T>(_ attr: Ax.Attr<T>, _ value: T) -> Bool {
        AXUIElementSetAttributeValue(self, attr.value as CFString, attr.setter(value)) == .success
    }
}
