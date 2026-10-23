import Foundation

@MainActor private var lastKnownNativeFocusedWindowId: UInt32? = nil
@MainActor private var expectedNativeFocus: (windowId: UInt32, deadline: Date)? = nil

/// macOS might natively focus other windows on the way to the window (e.g. raising a window can activate its app).
/// Don't take those intermediate focus changes from macOS until it focuses the window, or until the deadline passes
@MainActor func expectNativeFocus(_ window: Window) {
    let windowId = window.windowId
    expectedNativeFocus = (windowId, Date.now.addingTimeInterval(1))
    Task.startUnstructured { @MainActor in
        try await Task.sleep(for: .seconds(1))
        // macOS didn't focus the window in time. Take whatever it focused instead
        if expectedNativeFocus?.windowId == windowId {
            scheduleCancellableCompleteRefreshSession(.expectedNativeFocusTimeout)
        }
    }
}

@MainActor var isNativeFocusExpected: Bool { expectedNativeFocus.map { Date.now < $0.deadline } ?? false }

/// The data should flow (from nativeFocused to focused) and
///                      (from nativeFocused to lastKnownNativeFocusedWindowId)
/// Alternative names: takeFocusFromMacOs, syncFocusFromMacOs
@MainActor func updateFocusCache(_ nativeFocused: Window?) {
    if nativeFocused?.parent is MacosPopupWindowsContainer {
        return
    }
    if let expected = expectedNativeFocus {
        if nativeFocused?.windowId != expected.windowId && Date.now < expected.deadline { return }
        expectedNativeFocus = nil
    }
    if nativeFocused?.windowId != lastKnownNativeFocusedWindowId {
        _ = nativeFocused?.focusWindow()
        lastKnownNativeFocusedWindowId = nativeFocused?.windowId
    }
    nativeFocused?.macAppUnsafe.lastNativeFocusedWindowId = nativeFocused?.windowId
}
