private var _focusedApp: NSRunningApplication? = nil
var appForTests: AeroApp? = nil

var focusedApp: AeroApp? {
    if isUnitTest {
        return appForTests
    } else {
        precondition(appForTests == nil)
        if NSWorkspace.shared.frontmostApplication == _focusedApp {
            _focusedApp = nil
        }
        return _focusedApp?.macApp ?? NSWorkspace.shared.frontmostApplication?.macApp
    }
}

var focusedWindow: Window? { focusedApp?.focusedWindow }

var focusedWindowOrEffectivelyFocused: Window? {
    focusedWindow ?? Workspace.focused.mostRecentWindow ?? Workspace.focused.anyLeafWindowRecursive
}

// It's fine to call this inaccurate during startup
private var _focusedWorkspaceName: String = focusedMonitorInaccurate?.activeWorkspace.name
    ?? mainMonitor.activeWorkspace.name
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
