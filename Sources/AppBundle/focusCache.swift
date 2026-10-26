@MainActor private var lastKnownNativeFocusedWindowId: UInt32? = nil
@MainActor private var lastKnownNativeFocusedApp: (any AbstractApp)? = nil

/// The data should flow (from nativeFocused to focused) and
///                      (from nativeFocused to lastKnownNativeFocusedWindowId)
/// Alternative names: takeFocusFromMacOs, syncFocusFromMacOs
@MainActor func updateFocusCache(_ nativeFocused: Window?) {
    if nativeFocused?.parent is MacosPopupWindowsContainer {
        return
    }
    if nativeFocused?.windowId != lastKnownNativeFocusedWindowId {
        if !isFocusHandedOverByQuittingApp(nativeFocused, prevApp: lastKnownNativeFocusedApp) {
            _ = nativeFocused?.focusWindow()
        }
        lastKnownNativeFocusedWindowId = nativeFocused?.windowId
    }
    if let nativeFocused { lastKnownNativeFocusedApp = nativeFocused.app }
    nativeFocused?.macAppUnsafe.lastNativeFocusedWindowId = nativeFocused?.windowId
}

/// When the focused app quits, macOS activates the app that was used before it.
/// Following that app would switch to its workspace (and the dead window's garbage collection switches back a moment later).
/// By that time, the dead window might be already garbage collected, that's why the app is remembered separately
@MainActor func isFocusHandedOverByQuittingApp(_ nativeFocused: Window?, prevApp: (any AbstractApp)?) -> Bool {
    guard config.stayOnWorkspaceWhenAppQuits, let nativeFocused, let prevApp else { return false }
    return prevApp.isTerminated && nativeFocused.nodeWorkspace != focus.workspace
}
