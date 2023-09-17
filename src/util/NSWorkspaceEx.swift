private var _focusedApp: NSRunningApplication? = nil

var focusedApp: NSRunningApplication? {
    /// Force assign currently active app in scope of this session
    set { _focusedApp = newValue }
    get { _focusedApp ?? NSWorkspace.shared.frontmostApplication }
}

var focusedWindow: MacWindow? { focusedApp?.macApp?.focusedWindow }
