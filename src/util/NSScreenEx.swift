import Foundation

extension NSScreen {
    /// Motivation:
    /// 1. NSScreen.main is a misleading name.
    /// 2. NSScreen.main doesn't work correctly from NSWorkspace.didActivateApplicationNotification &
    ///    kAXFocusedWindowChangedNotification callbacks.
    ///
    /// I hate you Apple
    ///
    /// Returns `nil` if the desktop is selected (which is when the app is active but doesn't show any window)
    static var focusedMonitorOrNilIfDesktop: Monitor? {
        NSWorkspace.activeApp?.macApp?.focusedWindow?.getTopLeftCorner()?.monitorApproximation
                ?? NSScreen.screens.singleOrNil()?.monitor

        //NSWorkspace.activeApp?.macApp?.axFocusedWindow?
        //        .get(Ax.topLeftCornerAttr)?.monitorApproximation
        //        ?? NSScreen.screens.singleOrNil()

    }

    var isMainMonitor: Bool {
        frame.minX == 0 && frame.minY == 0
    }

    /// The property is a replacement for Apple's crazy ``frame``
    ///
    /// - For ``MacWindow.topLeftCorner``, (0, 0) is main screen top left corner, and positive y-axis goes down.
    /// - For ``frame``, (0, 0) is main screen bottom left corner, and positive y-axis goes up (which is crazy).
    ///
    /// The property "normalizes" ``frame``
    var rect: Rect { frame.monitorFrameNormalized() }

    /// Same as ``rect`` but for ``visibleFrame``
    var visibleRect: Rect { visibleFrame.monitorFrameNormalized() }
}
