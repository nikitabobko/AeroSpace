@MainActor private var lastKnownNativeFocusedWindowId: UInt32? = nil

// /// The data should flow (from nativeFocused to focused) and
// ///                      (from nativeFocused to lastKnownNativeFocusedWindowId)
// /// Alternative names: takeFocusFromMacOs, syncFocusFromMacOs

// @MainActor func updateFocusCache(_ nativeFocused: Window?) {
//     if nativeFocused?.parent is MacosPopupWindowsContainer {
//         return
//     }
//     if nativeFocused?.windowId != lastKnownNativeFocusedWindowId {
//         _ = nativeFocused?.focusWindow()
//         lastKnownNativeFocusedWindowId = nativeFocused?.windowId
//     }
// }

// This now prevents switching workspaces when activating an application
// Selecting apps (with open windows in other workspaces) doesn't jump there
// If switching is still desired, this can be expanded with a boolean flag
@MainActor
func updateFocusCache(_ nativeFocused: Window?) {
    if nativeFocused?.parent is MacosPopupWindowsContainer { return }
    guard nativeFocused?.windowId != lastKnownNativeFocusedWindowId else { return }

    if let nf = nativeFocused {
        if let nfWs = nf.visualWorkspace {
            if nfWs !== focus.workspace {
                // App activated, but on other workspace
                // don't perform switching
                lastKnownNativeFocusedWindowId = nf.windowId
                return
            }
        } else {
            lastKnownNativeFocusedWindowId = nf.windowId
            return
        }
    }

    _ = nativeFocused?.focusWindow()
    lastKnownNativeFocusedWindowId = nativeFocused?.windowId
}
