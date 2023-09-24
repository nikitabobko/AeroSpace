private var _focusedApp: NSRunningApplication? = nil
var focusedAppForTests: AeroApp? = nil

func defocusAllWindows() {
    // Since AeroSpace doesn't show any windows, focusing AeroSpace defocuses all windows
    let current = NSRunningApplication.current
    precondition(current.activate(options: .activateIgnoringOtherApps))
    _focusedApp = current
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

var focusedWindow: Window? { focusedApp?.focusedWindow }

var focusedWindowOrEffectivelyFocused: Window? {
    focusedWindow ?? Workspace.focused.mruWindows.mostRecent ?? Workspace.focused.anyLeafWindowRecursive
}
