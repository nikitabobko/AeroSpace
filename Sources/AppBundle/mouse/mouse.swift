import AppKit

@MainActor var currentlyManipulatedWithMouseWindowId: UInt32? = nil
var isLeftMouseButtonDown: Bool { NSEvent.pressedMouseButtons == 1 }

@MainActor
func isManipulatedWithMouse(_ window: Window) async throws -> Bool {
    try await (!window.isHiddenInCorner && // Don't allow to resize/move windows of hidden workspaces
        isLeftMouseButtonDown &&
        (currentlyManipulatedWithMouseWindowId == nil || window.windowId == currentlyManipulatedWithMouseWindowId))
        .andAsync { @Sendable @MainActor in try await getNativeFocusedWindow() == window }
}

/// Same motivation as in monitorFrameNormalized
var mouseLocation: CGPoint {
    let mainMonitorHeight: CGFloat = mainMonitor.height
    let location = NSEvent.mouseLocation
    return location.copy(\.y, mainMonitorHeight - location.y)
}
