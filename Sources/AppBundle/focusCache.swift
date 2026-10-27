import Common

@MainActor private var lastKnownNativeFocusedWindowId: UInt32? = nil

/// The data should flow (from nativeFocused to focused) and
///                      (from nativeFocused to lastKnownNativeFocusedWindowId)
/// Alternative names: takeFocusFromMacOs, syncFocusFromMacOs
@MainActor func updateFocusCache(_ nativeFocused: Window?) {
    if nativeFocused?.parent is MacosPopupWindowsContainer {
        return
    }
    if nativeFocused?.windowId != lastKnownNativeFocusedWindowId {
        // macOS hands focus to applications on its own: notification banners, background apps,
        // apps finishing their launch. Following that focus blindly calls focusWindow(), which
        // makes the window's workspace visible on its monitor — i.e. the visible workspace
        // switches under the user while they are working somewhere else.
        //
        // With `focus-follows-app-activation = false`, a passive trigger (app activation, an
        // AX-reported focus change, a display event) no longer reveals a workspace that is
        // visible nowhere. Instead the native focus is pulled BACK to the window AeroSpace has
        // focused: blocking the reveal alone would leave the app's window parked off-screen
        // while still holding native keyboard focus, so the user would type into a window they
        // cannot see. Deliberate actions (hotkey, CLI command, mouse click, menu bar,
        // focus-follows-mouse) keep the stock behaviour.
        let wouldYankTheScreen = !config.revealWorkspaceOnPassiveFocus
            && !(refreshSessionEvent?.isExplicitUserTrigger ?? false)
            && nativeFocused?.visualWorkspace.map { !$0.isVisible } == true
        if wouldYankTheScreen, let focusToRestore = focus.windowOrNil {
            // Pull the native focus back to the window AeroSpace has focused, so the screen AND
            // the keyboard stay where the user is. Only safe when there IS such a window: the
            // fallback below must stay reachable, because a reveal is recoverable while leaving
            // the keyboard on a parked off-screen window (typing into an invisible app) is not.
            focusToRestore.nativeFocus()
        } else {
            _ = nativeFocused?.focusWindow()
        }
        lastKnownNativeFocusedWindowId = nativeFocused?.windowId
    }
    nativeFocused?.macAppUnsafe.lastNativeFocusedWindowId = nativeFocused?.windowId
}
