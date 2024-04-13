private var lastKnownNativeFocusedWindowId: UInt32? = nil

/// The data should flow (from nativeFocused to focusedWindow) and
///                      (from nativeFocused to lastKnownNativeFocusedWindowId)
/// Alternative names: takeFocusFromMacOs, syncFocusFromMacOs
func updateFocusCache(_ nativeFocused: Window?) {
    if nativeFocused?.windowId != lastKnownNativeFocusedWindowId {
        _ = nativeFocused?.focus()
        lastKnownNativeFocusedWindowId = nativeFocused?.windowId
    }
}
