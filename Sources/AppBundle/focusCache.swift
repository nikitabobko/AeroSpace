import AppKit
import Common

@MainActor private var lastKnownNativeFocusedWindowId: OpaqueWindowId? = nil

@MainActor func recordAeroSpaceNativeFocus(_ windowId: OpaqueWindowId, app: MacApp) {
    lastKnownNativeFocusedWindowId = windowId
    app.lastFocusedNativeWindowOpaqueId = windowId
}

@MainActor func onAppActivatedInWorkspace(_ pid: pid_t) {}

/// The data should flow (from nativeFocused to focused) and
///                      (from nativeFocused to lastKnownNativeFocusedWindowId)
/// Alternative names: takeFocusFromMacOs, syncFocusFromMacOs
@MainActor func updateFocusCache(_ nativeFocused: Window?) {
    if nativeFocused?.parent is MacosPopupWindowsContainer {
        return
    }
    if !isUnitTest, let winWorkspace = nativeFocused?.nodeWorkspace, !winWorkspace.isVisible {
        if case .globalObserver(let notif) = refreshSessionEvent,
           notif == NSWorkspace.didActivateApplicationNotification.rawValue,
           let appPid = nativeFocused?.app.pid,
           let visibleWin = globalFocus.workspace.allLeafWindowsRecursiveMru.first(where: { $0.app.pid == appPid })
        {
            _ = visibleWin.focusWindow()
            lastKnownNativeFocusedWindowId = visibleWin.windowId
        }
        return
    }
    if nativeFocused?.windowId != lastKnownNativeFocusedWindowId {
        _ = nativeFocused?.focusWindow()
        lastKnownNativeFocusedWindowId = nativeFocused?.windowId
    }
    nativeFocused?.macAppUnsafe.lastFocusedNativeWindowOpaqueId = nativeFocused?.windowId
}
