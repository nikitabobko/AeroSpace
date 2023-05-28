import Foundation
import AppKit
import Accessibility
import Cocoa
import Darwin
import ApplicationServices
import ScriptingBridge

func requireAccessibilityPermissions() {
    let trusted = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
    let privOptions = [trusted: true] as CFDictionary
    AXIsProcessTrustedWithOptions(privOptions)
}

func resizeFrontmostWindow(width: CGFloat, height: CGFloat) {
    let pid = pid_t(84786) // Replace with the process ID of the application

    let app = AXUIElementCreateApplication(pid)
    var windowRaw: AnyObject?
    AXUIElementCopyAttributeValue(app, kAXMainWindowAttribute as CFString, &windowRaw)
    let window = windowRaw as! AXUIElement
    print(window)
    // kAXWindowsAttribute

    var windowTitleRaw: AnyObject?
    AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &windowTitleRaw)
    let windowTitle = windowTitleRaw as! String
    print(windowTitle)

    var foo = CGSize(width: 800, height: 600)
    let size = AXValueCreate(.cgSize, &foo)
    let position = CGPoint(x: 100, y: 100)
//    let minSize = CGSize(width: 400, height: 300)
//    let maxSize = CGSize(width: 1200, height: 900)
//    AXUIElementGetAttributeValue()

    kAXFocusedAttribute
    kAXFrontmostAttribute
//    kAXHiddenAttribute
    print("--- here we go")
    let x = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, size as CFTypeRef)
    print(x == AXError.success)
    print(x.rawValue)
    let y = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position as CFTypeRef)
    print(y == AXError.success)
    print(y.rawValue)
//    AXUIElementSetAttributeValue(window as! AXUIElement, kAXMinSizeAttribute as CFString, minSize as CFTypeRef)
//    AXUIElementSetAttributeValue(window as! AXUIElement, kAXMaxSizeAttribute as CFString, maxSize as CFTypeRef)
}

//extension NSWindow {
//    var axuiElement: AXUIElement {
//        guard let windowRef = windowRef else {
//            fatalError("Unable to get window reference")
//        }
//        return AXUIElementCreateWithHIObjectAndPID(windowRef, UInt32(processIdentifier))!.takeRetainedValue()
//    }
//}


//func resize2() {
//    let finder: SBApplication = SBApplication(bundleIdentifier: "com.apple.finder")!
//    if let window = finder.windows.first {
//        // Set the new window size
//        let newSize = NSSize(width: 800, height: 600)
//        var newFrame = window.frame
//        newFrame.size = newSize
//        // Set the window frame to the new size
//        window.frame = newFrame
//    }
//}

// Example usage:
//resizeFrontmostWindowOf(processName: "Safari", width: 800, height: 600)
