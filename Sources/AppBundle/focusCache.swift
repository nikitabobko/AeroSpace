@MainActor private var lastKnownNativeFocusedWindowId: UInt32? = nil

/// The data should flow (from nativeFocused to focused) and
///                      (from nativeFocused to lastKnownNativeFocusedWindowId)
/// Alternative names: takeFocusFromMacOs, syncFocusFromMacOs
@MainActor func updateFocusCache(_ nativeFocused: Window?) {
    if nativeFocused?.parent is MacosPopupWindowsContainer {
        return
    }
    if nativeFocused?.windowId != lastKnownNativeFocusedWindowId {
        _ = nativeFocused?.focusWindow()
        lastKnownNativeFocusedWindowId = nativeFocused?.windowId
    }
    // Dialogs/sheets (e.g. Finder's "Connect to Server") aren't native-tab group members. Letting
    // one become the replacement candidate poisons the comparison: it closes normally later, so
    // whichever tiled window is actually mid-tab-swap when it closes never gets matched.
    if !(nativeFocused?.parent is FloatingWindowsContainer) {
        nativeFocused?.macAppUnsafe.lastNativeFocusedWindowId = nativeFocused?.windowId
    }
}
