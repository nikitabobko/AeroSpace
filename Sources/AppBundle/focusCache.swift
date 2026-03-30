@MainActor private var lastKnownNativeFocusedWindowId: UInt32? = nil

/// The data should flow (from nativeFocused to focused) and
///                      (from nativeFocused to lastKnownNativeFocusedWindowId)
/// Alternative names: takeFocusFromMacOs, syncFocusFromMacOs
@MainActor func updateFocusCache(_ nativeFocused: Window?) {
    if nativeFocused?.parent is MacosPopupWindowsContainer {
        return
    }
    if nativeFocused?.windowId != lastKnownNativeFocusedWindowId {
        if shouldAllowFocusChange(to: nativeFocused) {
            _ = nativeFocused?.focusWindow()
            lastKnownNativeFocusedWindowId = nativeFocused?.windowId
        } else {
            // Refocus the previously focused window to resist the steal
            if let currentWindow = focus.windowOrNil {
                currentWindow.nativeFocus()
            }
            return
        }
    }
    nativeFocused?.macAppUnsafe.lastNativeFocusedWindowId = nativeFocused?.windowId
}
