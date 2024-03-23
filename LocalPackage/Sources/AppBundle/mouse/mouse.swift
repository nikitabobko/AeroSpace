import AppKit
var currentlyManipulatedWithMouseWindowId: UInt32? = nil
var isLeftMouseButtonPressed: Bool { NSEvent.pressedMouseButtons == 1 }

/// Same motivation as in monitorFrameNormalized
var mouseLocation: CGPoint {
    let mainMonitorHeight: CGFloat = mainMonitor.height
    let location = NSEvent.mouseLocation
    return location.copy(\.y, mainMonitorHeight - location.y)
}
