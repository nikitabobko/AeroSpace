import AppKit
import Common
import CoreGraphics

@MainActor private var focusFollowsMouseMonitor: Any? = nil
@MainActor private var focusFollowsMouseTask: Task<(), any Error>? = nil

@MainActor
func installFocusFollowsMouseMonitor() {
    if let monitor = focusFollowsMouseMonitor {
        NSEvent.removeMonitor(monitor)
        focusFollowsMouseMonitor = nil
    }
    focusFollowsMouseTask?.cancel()
    focusFollowsMouseTask = nil

    if !config.focusFollowsMouse { return }

    focusFollowsMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
        Task { @MainActor in
            handleMouseMoveForFocusFollows()
        }
    }
}

/// CGWindowListCopyWindowInfo returns windows in front-to-back order so first
/// returned window is visually the topmost one.
@MainActor
private func resolveTopmostWindowUnderCursor(_ point: CGPoint) -> Window? {
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    guard let cfArray = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [CFDictionary] else { return nil }
    for elem in cfArray {
        let dict = elem as NSDictionary
        guard let _windowId = dict[kCGWindowNumber] else { continue }
        let windowId = ((_windowId as! CFNumber) as NSNumber).uint32Value
        guard let window = Window.get(byId: windowId) else { continue }
        guard let boundsDict = dict[kCGWindowBounds] else { continue }
        guard let bounds = CGRect(dictionaryRepresentation: boundsDict as! CFDictionary) else { continue }
        if bounds.contains(point) {
            return window
        }
    }
    return nil
}

@MainActor
private func handleMouseMoveForFocusFollows() {
    guard let token: RunSessionGuard = .isServerEnabled else { return }
    guard !isLeftMouseButtonDown else { return }

    let mouseLocation = mouseLocation
    let targetWindow = resolveTopmostWindowUnderCursor(mouseLocation)

    guard let targetWindow else { return }
    guard targetWindow.windowId != focus.windowOrNil?.windowId else { return }
    guard targetWindow.visualWorkspace != nil else { return }

    focusFollowsMouseTask?.cancel()
    focusFollowsMouseTask = Task {
        try checkCancellation()
        try await runLightSession(.focusFollowsMouse, token) {
            _ = targetWindow.focusWindow()
            targetWindow.nativeFocus()
        }
    }
}
