import Common

private let clock = ContinuousClock()

struct NativeFocusRaceProtection {
    // macOS chooses a replacement focused window asynchronously after a close.
    // Ignore only the short cross-workspace fallout of that choice.
    static let closeProtectionDuration: Duration = .milliseconds(250)
    // App activation can arrive just before the window-created notification.
    // Give the new window time to be registered on the current workspace.
    static let appActivationGraceDuration: Duration = .milliseconds(150)
    // Launch Services and launchers such as Raycast can emit delayed app
    // activations well after a new window is visible.  An explicit workspace
    // command is newer user intent and must win over that startup fallout.
    static let workspaceSwitchProtectionDuration: Duration = .seconds(3)

    private struct ProtectedClose {
        let workspaceName: String
        let expiresAt: ContinuousClock.Instant
    }

    private struct AppActivation {
        let appPid: Int32
        let expiresAt: ContinuousClock.Instant
    }

    private struct ProtectedWorkspaceSwitch {
        let workspaceName: String
        let expiresAt: ContinuousClock.Instant
    }

    private var protectedClose: ProtectedClose?
    private var appActivation: AppActivation?
    private var protectedWorkspaceSwitch: ProtectedWorkspaceSwitch?

    mutating func recordWindowClose(
        workspaceName: String,
        now: ContinuousClock.Instant = clock.now,
    ) {
        protectedClose = ProtectedClose(
            workspaceName: workspaceName,
            expiresAt: now.advanced(by: Self.closeProtectionDuration),
        )
    }

    mutating func recordAppActivation(
        appPid: Int32,
        now: ContinuousClock.Instant = clock.now,
    ) {
        appActivation = AppActivation(
            appPid: appPid,
            expiresAt: now.advanced(by: Self.appActivationGraceDuration),
        )
    }

    mutating func clearAppActivation(appPid: Int32) {
        if appActivation?.appPid == appPid {
            appActivation = nil
        }
    }

    mutating func recordWorkspaceSwitch(
        workspaceName: String,
        now: ContinuousClock.Instant = clock.now,
    ) {
        protectedWorkspaceSwitch = ProtectedWorkspaceSwitch(
            workspaceName: workspaceName,
            expiresAt: now.advanced(by: Self.workspaceSwitchProtectionDuration),
        )
    }

    mutating func clearWorkspaceSwitch() {
        protectedWorkspaceSwitch = nil
    }

    func shouldSuppressAfterWorkspaceSwitch(
        currentWorkspaceName: String,
        nativeWorkspaceName: String,
        now: ContinuousClock.Instant = clock.now,
    ) -> Bool {
        guard let protectedWorkspaceSwitch,
              now < protectedWorkspaceSwitch.expiresAt
        else { return false }
        return protectedWorkspaceSwitch.workspaceName == currentWorkspaceName &&
            nativeWorkspaceName != currentWorkspaceName
    }

    func shouldSuppressAfterClose(
        currentWorkspaceName: String,
        nativeWorkspaceName: String,
        now: ContinuousClock.Instant = clock.now,
    ) -> Bool {
        guard let protectedClose, now < protectedClose.expiresAt else { return false }
        return protectedClose.workspaceName == currentWorkspaceName &&
            nativeWorkspaceName != currentWorkspaceName
    }

    func appActivationDelay(
        appPid: Int32,
        currentWorkspaceName: String,
        nativeWorkspaceName: String,
        now: ContinuousClock.Instant = clock.now,
    ) -> Duration? {
        guard let appActivation,
              appActivation.appPid == appPid,
              now < appActivation.expiresAt,
              nativeWorkspaceName != currentWorkspaceName
        else { return nil }
        return now.duration(to: appActivation.expiresAt)
    }
}

@MainActor private var lastKnownNativeFocusedWindowId: UInt32? = nil
@MainActor private var raceProtection = NativeFocusRaceProtection()
@MainActor private var deferredNativeFocusTask: Task<(), Never>? = nil

@MainActor
func protectFocusAfterWindowClose(workspaceName: String) {
    raceProtection.recordWindowClose(workspaceName: workspaceName)
}

@MainActor
func noteNativeAppActivation(appPid: Int32) {
    raceProtection.recordAppActivation(appPid: appPid)
}

@MainActor
func protectFocusAfterWorkspaceSwitch(workspaceName: String) {
    raceProtection.recordWorkspaceSwitch(workspaceName: workspaceName)
}

@MainActor
func cancelFocusProtectionAfterWorkspaceSwitch() {
    raceProtection.clearWorkspaceSwitch()
}

@MainActor
private func scheduleDeferredNativeFocus(after delay: Duration) {
    deferredNativeFocusTask?.cancel()
    deferredNativeFocusTask = Task.startUnstructured { @MainActor in
        do {
            try await Task.sleep(for: delay)
        } catch {
            return
        }
        if !Task.isCancelled {
            scheduleCancellableCompleteRefreshSession(.deferredNativeFocus)
        }
    }
}

@MainActor
private func updateLastNativeFocusedWindow(_ window: Window?) {
    (window as? MacWindow)?.macApp.lastNativeFocusedWindowId = window?.windowId
}

/// The data should flow (from nativeFocused to focused) and
///                      (from nativeFocused to lastKnownNativeFocusedWindowId)
/// Alternative names: takeFocusFromMacOs, syncFocusFromMacOs
@MainActor func updateFocusCache(_ nativeFocused: Window?) {
    if nativeFocused?.parent is MacosPopupWindowsContainer {
        return
    }
    guard nativeFocused?.windowId != lastKnownNativeFocusedWindowId else {
        updateLastNativeFocusedWindow(nativeFocused)
        return
    }

    guard let nativeFocused, let nativeWorkspace = nativeFocused.visualWorkspace else {
        deferredNativeFocusTask?.cancel()
        lastKnownNativeFocusedWindowId = nil
        updateLastNativeFocusedWindow(nil)
        return
    }

    let currentWorkspaceName = focus.workspace.name
    let nativeWorkspaceName = nativeWorkspace.name
    let appPid = nativeFocused.app.pid

    if nativeWorkspaceName == currentWorkspaceName {
        raceProtection.clearAppActivation(appPid: appPid)
    } else if raceProtection.shouldSuppressAfterWorkspaceSwitch(
        currentWorkspaceName: currentWorkspaceName,
        nativeWorkspaceName: nativeWorkspaceName,
    ) {
        deferredNativeFocusTask?.cancel()
        if let intendedFocus = focus.windowOrNil {
            intendedFocus.nativeFocus()
            lastKnownNativeFocusedWindowId = intendedFocus.windowId
            updateLastNativeFocusedWindow(intendedFocus)
        }
        return
    } else if raceProtection.shouldSuppressAfterClose(
        currentWorkspaceName: currentWorkspaceName,
        nativeWorkspaceName: nativeWorkspaceName,
    ) {
        deferredNativeFocusTask?.cancel()
        lastKnownNativeFocusedWindowId = nativeFocused.windowId
        updateLastNativeFocusedWindow(nativeFocused)
        return
    } else if let delay = raceProtection.appActivationDelay(
        appPid: appPid,
        currentWorkspaceName: currentWorkspaceName,
        nativeWorkspaceName: nativeWorkspaceName,
    ) {
        scheduleDeferredNativeFocus(after: delay)
        updateLastNativeFocusedWindow(nativeFocused)
        return
    }

    deferredNativeFocusTask?.cancel()
    _ = nativeFocused.focusWindow()
    lastKnownNativeFocusedWindowId = nativeFocused.windowId
    updateLastNativeFocusedWindow(nativeFocused)
}
