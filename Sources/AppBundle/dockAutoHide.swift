import AppKit
import Common

// 'auto-hide-dock' config option.
//
// Mental model: when the focused workspace has 'auto-hide-dock' enabled and contains at least one tiling window, AeroSpace
// turns on macOS Dock auto-hide and lets the tiling windows take the space that the Dock used to occupy.
// Otherwise, the Dock is visible.
//
// The Dock is controlled via System Events (Automation permission is required). No private APIs are involved.

/// The Dock auto-hide value that AeroSpace believes is currently applied. nil if unknown
@MainActor private var appliedDockAutoHide: Bool? = nil
/// The Dock auto-hide value that the in-progress ``dockAutoHideTask`` applies
@MainActor private var pendingDockAutoHide: Bool? = nil
/// The Dock change that is in progress. Layouts wait for it
@MainActor private var dockAutoHideTask: Task<Void, Never>? = nil
/// Set when a layout stopped waiting for ``dockAutoHideTask``. The layout must be redone once the task is done
@MainActor private var isRelayoutNeededAfterDockAutoHideTask: Bool = false
/// Set when AeroSpace isn't allowed to control the Dock (Automation permission is denied). Reset on config reload
@MainActor private var isDockAutomationBroken: Bool = false
@MainActor private var lastDockAutoHideFailure: ContinuousClock.Instant? = nil

private let dockBundleId = "com.apple.dock"
/// For how long layouts wait for the Dock change. Normally, the change takes a fraction of a second.
/// But e.g. the first change shows the Automation permission dialog that blocks until the user answers it
private let layoutDockWaitTimeout: Duration = .seconds(1)
private let retryAfterFailureTimeout: Duration = .seconds(5)

extension Workspace {
    /// Same as ``MonitorInfo/visibleRect`` of the workspace monitor, but includes the area of the Dock
    /// if AeroSpace auto-hides the Dock for this workspace
    @MainActor
    var layoutVisibleRect: Rect {
        let monitor = workspaceMonitorInfo
        let visibleRect = monitor.visibleRect
        guard isDockAutoHiddenByAeroSpace(for: self) else { return visibleRect }
        let rect = monitor.rect
        // The Dock can be placed only at the left, right, or bottom edge. The top edge is occupied by the menu bar
        return Rect(
            topLeftX: rect.minX,
            topLeftY: visibleRect.minY,
            width: rect.width,
            height: rect.maxY - visibleRect.minY,
        )
    }

    @MainActor
    var layoutVisibleRectPaddedByOuterGaps: Rect {
        layoutVisibleRect.paddedByOuterGaps(workspaceMonitorInfo)
    }
}

@MainActor
private var shouldAutoHideDock: Bool {
    guard TrayMenuModel.shared.isEnabled, !isDockAutomationBroken else { return false }
    let workspace = globalFocus.workspace
    return config.autoHideDock.isEnabled(forWorkspace: workspace.name) && !workspace.rootTilingContainer.isEffectivelyEmpty
}

/// Based on the actual Dock state, not on the desired one. Windows must not be laid out over the visible Dock
@MainActor
private func isDockAutoHiddenByAeroSpace(for workspace: Workspace) -> Bool {
    appliedDockAutoHide == true && config.autoHideDock.isEnabled(forWorkspace: workspace.name)
}

/// Must be called on every layout, before windows are laid out.
///
/// It waits until the Dock state is applied. Apps don't allow windows to be taller than NSScreen.visibleFrame,
/// so if windows were laid out while the Dock is still visible, apps would shrink them.
@MainActor
func syncDockAutoHide() async {
    if isUnitTest { return }
    // If the previous change is still in progress, the layout will be redone once it's done
    guard await waitForDockAutoHideTask() else { return }
    if isDockAutomationBroken { return }
    if let lastDockAutoHideFailure, ContinuousClock.now - lastDockAutoHideFailure < retryAfterFailureTimeout { return }
    let target = shouldAutoHideDock
    if config.autoHideDock == .disabled && appliedDockAutoHide != true {
        return // Don't fight with the user if AeroSpace hasn't hidden the Dock
    }
    let current = appliedDockAutoHide ?? readDockPreference("autohide") as? Bool ?? false
    appliedDockAutoHide = current
    if target == current { return }

    pendingDockAutoHide = target
    startDockAutoHideTask { @MainActor in
        let visibleFramesBefore = NSScreen.screens.map(\.visibleFrame)
        switch await setDockAutoHide(target) {
            case .success:
                appliedDockAutoHide = target
                lastDockAutoHideFailure = nil
                await waitForVisibleFramesChange(from: visibleFramesBefore)
                refreshMonitorInfos()
            case .notAuthorized:
                isDockAutomationBroken = true
                appliedDockAutoHide = nil
            case .failure: // E.g. the Dock or System Events are restarting
                lastDockAutoHideFailure = .now
                appliedDockAutoHide = nil
        }
        pendingDockAutoHide = nil
    }
    _ = await waitForDockAutoHideTask()
}

/// Called on every config reload (including the startup).
///
/// Makes sure that the Dock is visible (unless it's AeroSpace who hid it) and that the Dock hides and shows instantly.
/// Otherwise, the Dock hide animation is visible every time AeroSpace auto-hides the Dock.
/// The Dock reads its preferences only on its startup, that's why it's restarted.
/// It's done only if the preferences have unexpected values, so the Dock is restarted at most once.
@MainActor
func syncDockAutoHideConfig() {
    isDockAutomationBroken = false
    lastDockAutoHideFailure = nil
    if isUnitTest || config.autoHideDock == .disabled { return }
    // Don't race with the change in progress. The preferences will be checked on the next config reload
    if dockAutoHideTask != nil { return }
    let expectedAutoHide = appliedDockAutoHide == true
    var isChanged = false
    if readDockPreference("autohide-time-modifier") as? Double != 0 {
        CFPreferencesSetAppValue("autohide-time-modifier" as CFString, 0.0 as CFNumber, dockBundleId as CFString)
        isChanged = true
    }
    if readDockPreference("autohide") as? Bool != expectedAutoHide {
        CFPreferencesSetAppValue("autohide" as CFString, expectedAutoHide as CFBoolean, dockBundleId as CFString)
        isChanged = true
    }
    appliedDockAutoHide = expectedAutoHide
    guard isChanged, CFPreferencesAppSynchronize(dockBundleId as CFString) else { return }

    let oldDockPid = runningDock()?.processIdentifier
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/killall")
    process.arguments = ["Dock"]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return }

    // Layouts wait for the Dock to restart, so that windows are laid out against the new visible frame
    isRelayoutNeededAfterDockAutoHideTask = true
    startDockAutoHideTask { @MainActor in
        let deadline = ContinuousClock.now + .seconds(3)
        while ContinuousClock.now < deadline {
            if let dock = runningDock(), dock.processIdentifier != oldDockPid, dock.isFinishedLaunching { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        await waitForVisibleFramesToSettle()
        refreshMonitorInfos()
    }
}

/// Shows the Dock if AeroSpace hid it. Synchronous, because it's called right before the termination
@MainActor
func restoreDockAutoHideBeforeTermination() {
    if isUnitTest || (appliedDockAutoHide != true && pendingDockAutoHide != true) { return }
    let process = newSetDockAutoHideProcess(false)
    if (try? process.run()) != nil {
        process.waitUntilExit()
    }
}

@MainActor
private func startDockAutoHideTask(_ body: @escaping @MainActor () async -> Void) {
    let task = Task.startUnstructured { @MainActor in await body() }
    dockAutoHideTask = task
    Task.startUnstructured { @MainActor in
        await task.value
        if dockAutoHideTask == task { dockAutoHideTask = nil }
        if isRelayoutNeededAfterDockAutoHideTask {
            isRelayoutNeededAfterDockAutoHideTask = false
            scheduleCancellableCompleteRefreshSession(.dockAutoHide)
        }
    }
}

/// - Returns: true if there is no Dock change in progress anymore
@MainActor
private func waitForDockAutoHideTask() async -> Bool {
    let deadline = ContinuousClock.now + layoutDockWaitTimeout
    // Polling, because Task.value can't be awaited with a timeout
    while dockAutoHideTask != nil {
        if ContinuousClock.now >= deadline || Task.isCancelled {
            isRelayoutNeededAfterDockAutoHideTask = true
            return false
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return true
}

@MainActor
private func waitForVisibleFramesChange(from visibleFramesBefore: [CGRect]) async {
    let deadline = ContinuousClock.now + .milliseconds(500)
    while ContinuousClock.now < deadline && NSScreen.screens.map(\.visibleFrame) == visibleFramesBefore {
        try? await Task.sleep(for: .milliseconds(10))
    }
}

/// Waits until the visible frames don't change for a while
@MainActor
private func waitForVisibleFramesToSettle() async {
    let deadline = ContinuousClock.now + .seconds(1)
    var lastVisibleFrames = NSScreen.screens.map(\.visibleFrame)
    var lastChange = ContinuousClock.now
    while ContinuousClock.now < deadline && ContinuousClock.now - lastChange < .milliseconds(200) {
        try? await Task.sleep(for: .milliseconds(20))
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        if visibleFrames != lastVisibleFrames {
            lastVisibleFrames = visibleFrames
            lastChange = .now
        }
    }
}

private func runningDock() -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: dockBundleId).first
}

private func readDockPreference(_ key: String) -> Any? {
    CFPreferencesAppSynchronize(dockBundleId as CFString)
    return CFPreferencesCopyAppValue(key as CFString, dockBundleId as CFString)
}

private func newSetDockAutoHideProcess(_ value: Bool) -> Process {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/osascript")
    process.arguments = ["-e", "tell application \"System Events\" to set autohide of dock preferences to \(value)"]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    return process
}

private enum SetDockAutoHideResult {
    case success, notAuthorized, failure
}

/// osascript is used instead of NSAppleScript because NSAppleScript blocks the main thread
private func setDockAutoHide(_ value: Bool) async -> SetDockAutoHideResult {
    let process = newSetDockAutoHideProcess(value)
    let stderr = Pipe()
    process.standardError = stderr
    return await withCheckedContinuation { (continuation: CheckedContinuation<SetDockAutoHideResult, Never>) in
        process.terminationHandler = { process in
            if process.terminationStatus == 0 {
                continuation.resume(returning: .success)
            } else {
                let output = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                // -1743: "Not authorized to send Apple events to System Events" (Automation permission is denied)
                continuation.resume(returning: output.contains("-1743") ? .notAuthorized : .failure)
            }
        }
        if (try? process.run()) == nil {
            process.terminationHandler = nil
            continuation.resume(returning: .failure)
        }
    }
}
