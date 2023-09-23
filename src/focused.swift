private var _focusedApp: NSRunningApplication? = nil

func setFocusedAppForCurrentRefreshSession(app: NSRunningApplication?) {
    _focusedApp = app
}

var focusedApp: AeroApp? { _focusedApp?.macApp ?? NSWorkspace.shared.frontmostApplication?.macApp }

var focusedWindow: Window? { focusedApp?.focusedWindow }

var focusedWindowOrEffectivelyFocused: Window? {
    focusedWindow ?? Workspace.focused.mruWindows.mostRecent ?? Workspace.focused.anyLeafWindowRecursive
}
