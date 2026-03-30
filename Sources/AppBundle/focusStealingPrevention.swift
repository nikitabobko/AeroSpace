import AppKit
import Common
import Foundation

/// Tracks whether the current focus change was initiated by the user (hotkey, mouse click, CLI command)
/// vs. an app stealing focus on its own (e.g. a timer firing, a notification activating an app).
@MainActor
private var _userInitiatedFocusChangeDeadline: Date = .distantPast

/// Call this when a user-initiated action occurs that should allow focus to change freely.
/// The grace period allows the resulting macOS notifications to flow through without being blocked.
@MainActor
func markUserInitiatedFocusChange() {
    _userInitiatedFocusChangeDeadline = Date().addingTimeInterval(1.0)
}

@MainActor
var isUserInitiatedFocusChange: Bool {
    Date() < _userInitiatedFocusChangeDeadline
}

/// Determines whether a focus change to `newWindow` should be blocked based on the
/// `prevent-focus-stealing` config setting.
///
/// Returns `true` if the focus change should be allowed, `false` if it should be blocked.
@MainActor
func shouldAllowFocusChange(to newWindow: Window?) -> Bool {
    let mode = config.preventFocusStealing
    guard mode != .off else { return true }
    guard !isUserInitiatedFocusChange else { return true }
    guard let newWindow else { return true }

    let currentFocus = focus

    switch mode {
    case .off:
        return true
    case .crossWorkspace:
        // Block if the new window is on a different workspace
        guard let newWorkspace = newWindow.nodeWorkspace else { return true }
        return newWorkspace == currentFocus.workspace
    case .always:
        // Block if the newly focused window differs from the current one at all
        guard let currentWindow = currentFocus.windowOrNil else { return true }
        return newWindow.windowId == currentWindow.windowId
    }
}
