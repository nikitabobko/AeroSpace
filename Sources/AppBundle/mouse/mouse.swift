import AppKit

@MainActor var currentlyManipulatedWithMouseWindowId: UInt32? = nil
private let leftMouseButtonMask = 1 << 0
private let rightMouseButtonMask = 1 << 1
var isLeftMouseButtonDown: Bool { (NSEvent.pressedMouseButtons & leftMouseButtonMask) != 0 }
var isRightMouseButtonDown: Bool { (NSEvent.pressedMouseButtons & rightMouseButtonMask) != 0 }

@MainActor
func isManipulatedWithMouse(_ window: Window) async throws -> Bool {
    try await (!window.isHiddenInCorner && // Don't allow to resize/move windows of hidden workspaces
        (isLeftMouseButtonDown || isRightMouseButtonDown) &&
        (currentlyManipulatedWithMouseWindowId == nil || window.windowId == currentlyManipulatedWithMouseWindowId))
        .andAsync { @Sendable @MainActor in try await getNativeFocusedWindow() == window }
}

/// Same motivation as in monitorFrameNormalized
var mouseLocation: CGPoint {
    let mainMonitorHeight: CGFloat = mainMonitor.height
    let location = NSEvent.mouseLocation
    return location.copy(\.y, mainMonitorHeight - location.y)
}
