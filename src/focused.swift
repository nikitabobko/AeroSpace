private var _focusedApp: NSRunningApplication? = nil
var focusedAppForTests: AeroApp? = nil

func defocusAllWindows() {
    if isUnitTest {
        focusedAppForTests = nil
    } else {
        // Since AeroSpace doesn't show any windows, focusing AeroSpace defocuses all windows
        let current = NSRunningApplication.current
        precondition(current.activate(options: .activateIgnoringOtherApps))
        _focusedApp = current
    }
}

var focusedApp: AeroApp? {
    if isUnitTest {
        return focusedAppForTests
    } else {
        precondition(focusedAppForTests == nil)
        if NSWorkspace.shared.frontmostApplication == _focusedApp {
            _focusedApp = nil
        }
        return _focusedApp?.macApp ?? NSWorkspace.shared.frontmostApplication?.macApp
    }
}

/// Motivation:
/// 1. NSScreen.main is a misleading name.
/// 2. NSScreen.main doesn't work correctly from NSWorkspace.didActivateApplicationNotification &
///    kAXFocusedWindowChangedNotification callbacks.
///
/// Returns `nil` if the desktop is selected (which is when the app is active but doesn't show any window)
var focusedMonitorOrNilIfDesktop: Monitor? {
    let window = focusedWindow as! MacWindow? // todo
    return window?.getCenter()?.monitorApproximation ?? monitors.singleOrNil()
    //NSWorkspace.activeApp?.macApp?.axFocusedWindow?
    //        .get(Ax.topLeftCornerAttr)?.monitorApproximation
    //        ?? NSScreen.screens.singleOrNil()
}

/// It's unsafe because NSScreen.main doesn't work correctly from NSWorkspace.didActivateApplicationNotification &
/// kAXFocusedWindowChangedNotification callbacks.
var focusedMonitorUnsafe: Monitor? {
    NSScreen.main?.monitor
}

var monitors: [Monitor] { NSScreen.screens.map(\.monitor) }

var focusedWindow: Window? { focusedApp?.focusedWindow }

var focusedWindowOrEffectivelyFocused: Window? {
    focusedWindow ?? Workspace.focused.mostRecentWindow ?? Workspace.focused.anyLeafWindowRecursive
}

private var _focusedWorkspaceName: String = focusedMonitorUnsafe?.getActiveWorkspace().name
    ?? mainMonitor.getActiveWorkspace().name
var focusedWorkspaceName: String {
    get { _focusedWorkspaceName }
    set {
        if newValue != _focusedWorkspaceName {
            previousFocusedWorkspaceName = _focusedWorkspaceName
        }
        _focusedWorkspaceName = newValue
    }
}
var previousFocusedWorkspaceName: String? = nil
