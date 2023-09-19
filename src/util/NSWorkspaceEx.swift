private var _focusedApp: NSRunningApplication? = nil

func setFocusedAppForCurrentRefreshSession(app: NSRunningApplication?) {
    _focusedApp = app
}

var focusedApp: MacApp? { _focusedApp?.macApp ?? NSWorkspace.shared.frontmostApplication?.macApp }

var focusedWindow: MacWindow? { focusedApp?.focusedWindow }

var focusedWindowOrEffectivelyFocused: Window? {
    focusedWindow ?? Workspace.focused.mruWindows.mostRecent ?? Workspace.focused.anyLeafWindowRecursive
}
