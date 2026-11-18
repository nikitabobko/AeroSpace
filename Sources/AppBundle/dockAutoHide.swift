import AppKit
import Common

// 'auto-hide-dock' config option.
//
// Mental model: when the focused workspace has 'auto-hide-dock' enabled and contains at least one tiling window
// or a floating window that overlaps the Dock, AeroSpace turns on macOS Dock auto-hide
// and lets the tiling windows take the space that the Dock used to occupy.
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
/// The area that the Dock occupies when it's visible. It's cached, because it can't be measured while the Dock is hidden
@MainActor private var visibleDockRect: Rect? = nil

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

/// Tiling windows always take the space of the Dock. Floating windows hide the Dock only if they overlap it
@MainActor
private func shouldAutoHideDock() async -> Bool {
    guard TrayMenuModel.shared.isEnabled, !isDockAutomationBroken else { return false }
    let workspace = globalFocus.workspace
    guard config.autoHideDock.isEnabled(forWorkspace: workspace.name) else { return false }
    if !workspace.rootTilingContainer.isEffectivelyEmpty { return true }
    guard let visibleDockRect else { return false }
    for window in workspace.floatingWindows {
        if let rect = try? await window.getAxRect(.cancellable), rect.ignoringEdges.intersects(visibleDockRect) {
            return true
        }
    }
    return false
}

@MainActor
private func updateVisibleDockRect() {
    guard appliedDockAutoHide == false else { return } // The Dock can be measured only while it's visible
    // The Dock can be placed only at the left, right, or bottom edge. The top edge is occupied by the menu bar
    let candidates: [Rect] = globalUnsortedMonitorInfos.flatMap { (monitor: MonitorInfo) -> [Rect] in
        let rect = monitor.rect
        let visibleRect = monitor.visibleRect
        return [
            Rect(topLeftX: rect.minX, topLeftY: visibleRect.maxY, width: rect.width, height: rect.maxY - visibleRect.maxY), // bottom
            Rect(topLeftX: rect.minX, topLeftY: visibleRect.minY, width: visibleRect.minX - rect.minX, height: visibleRect.height), // left
            Rect(topLeftX: visibleRect.maxX, topLeftY: visibleRect.minY, width: rect.maxX - visibleRect.maxX, height: visibleRect.height), // right
        ]
    }
    // The visible Dock is never thinner than that. Thinner insets are e.g. the reserved area of the hidden Dock.
    // The Dock doesn't necessarily occupy the whole screen edge, but there is no public API to get the Dock size.
    // (The Dock window itself covers the whole screen)
    visibleDockRect = candidates.filter { min($0.width, $0.height) >= 16 }.maxBy { min($0.width, $0.height) }
}

extension Rect {
    fileprivate func intersects(_ other: Rect) -> Bool {
        minX < other.maxX && other.minX < maxX && minY < other.maxY && other.minY < maxY
    }

    /// A window that only touches the Dock with its edge (e.g. the shadow area) shouldn't hide the Dock
    fileprivate var ignoringEdges: Rect {
        let insetX = min(6, width / 20)
        let insetY = min(6, height / 20)
        return Rect(topLeftX: topLeftX + insetX, topLeftY: topLeftY + insetY, width: width - 2 * insetX, height: height - 2 * insetY)
    }
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
    if config.autoHideDock == .disabled && appliedDockAutoHide != true {
        return // Don't fight with the user if AeroSpace hasn't hidden the Dock
    }
    let current = appliedDockAutoHide ?? readDockPreference("autohide") as? Bool ?? false
    appliedDockAutoHide = current
    updateVisibleDockRect()
    let target = await shouldAutoHideDock()
    // shouldAutoHideDock has a suspension point. Don't act on stale data
    if Task.isCancelled || dockAutoHideTask != nil || appliedDockAutoHide != current { return }
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
                Task.startUnstructured { @MainActor in
                    try? await Task.sleep(for: retryAfterFailureTimeout)
                    scheduleCancellableCompleteRefreshSession(.dockAutoHide)
                }
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
    while let task = dockAutoHideTask {
        guard !Task.isCancelled, await wait(for: task, until: deadline) else {
            isRelayoutNeededAfterDockAutoHideTask = true
            return false
        }
        if dockAutoHideTask == task { dockAutoHideTask = nil }
    }
    return true
}

/// Task.value can't be awaited with a timeout or cancellation
/// - Returns: true if the task is finished
@MainActor
private func wait(for task: Task<Void, Never>, until deadline: ContinuousClock.Instant) async -> Bool {
    let result = OneShotResult()
    return await withTaskCancellationHandler {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            result.continuation = continuation
            let timeout = Task.startUnstructured { @MainActor in
                try? await Task.sleep(until: deadline)
                result.resume(false)
            }
            Task.startUnstructured { @MainActor in
                await task.value
                timeout.cancel()
                result.resume(true)
            }
        }
    } onCancel: {
        Task.startUnstructured { @MainActor in result.resume(false) }
    }
}

@MainActor
private final class OneShotResult {
    var continuation: CheckedContinuation<Bool, Never>? = nil

    func resume(_ value: Bool) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}

/// The Dock updates the visible frame within a few milliseconds. Every millisecond delays the layout, so the polling is frequent
@MainActor
private func waitForVisibleFramesChange(from visibleFramesBefore: [CGRect]) async {
    let deadline = ContinuousClock.now + .milliseconds(500)
    while ContinuousClock.now < deadline && NSScreen.screens.map(\.visibleFrame) == visibleFramesBefore {
        try? await Task.sleep(for: .milliseconds(1))
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

private func setDockAutoHide(_ value: Bool) async -> SetDockAutoHideResult {
    switch await sendSetDockAutoHideAppleEvent(value) {
        case .success: return .success
        case .notAuthorized: return .notAuthorized
        case .failure: return await setDockAutoHideViaOsascript(value) // E.g. System Events isn't running. osascript launches it
    }
}

private let dockAppleEventQueue = DispatchQueue(label: "bobko.aerospace.dock-auto-hide")

/// `tell application "System Events" to set autohide of dock preferences to <value>`, but the Apple Event is sent directly.
/// It takes a few milliseconds, while osascript takes ~100ms (the process launch and the script compilation),
/// and the Dock change delays the layout, so it's noticeable on every workspace switch.
/// The event is sent on a separate queue, because the call blocks until System Events replies
private func sendSetDockAutoHideAppleEvent(_ value: Bool) async -> SetDockAutoHideResult {
    await withCheckedContinuation { (continuation: CheckedContinuation<SetDockAutoHideResult, Never>) in
        dockAppleEventQueue.async {
            let event = NSAppleEventDescriptor.appleEvent(
                withEventClass: fourCharCode("core"), // kAECoreSuite
                eventID: fourCharCode("setd"), // kAESetData
                targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: "com.apple.systemevents"),
                returnID: -1, // kAutoGenerateReturnID
                transactionID: 0, // kAnyTransactionID
            )
            // 'dpas' is 'dock preferences' property of the application. 'dahd' is its 'autohide' property
            let autohide = propertySpecifier(fourCharCode("dahd"), of: propertySpecifier(fourCharCode("dpas"), of: .null()))
            event.setParam(autohide, forKeyword: fourCharCode("----")) // keyDirectObject
            event.setParam(NSAppleEventDescriptor(boolean: value), forKeyword: fourCharCode("data")) // keyAEData
            let result: SetDockAutoHideResult
            do {
                _ = try event.sendEvent(options: [.waitForReply], timeout: 5)
                result = .success
            } catch {
                // -1743: errAEEventNotPermitted (Automation permission is denied)
                result = (error as NSError).code == -1743 ? .notAuthorized : .failure
            }
            continuation.resume(returning: result)
        }
    }
}

private func propertySpecifier(_ property: FourCharCode, of container: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
    let specifier = NSAppleEventDescriptor.record()
    specifier.setDescriptor(NSAppleEventDescriptor(typeCode: fourCharCode("prop")), forKeyword: fourCharCode("want")) // keyAEDesiredClass: cProperty
    specifier.setDescriptor(NSAppleEventDescriptor(enumCode: fourCharCode("prop")), forKeyword: fourCharCode("form")) // keyAEKeyForm: formPropertyID
    specifier.setDescriptor(NSAppleEventDescriptor(typeCode: property), forKeyword: fourCharCode("seld")) // keyAEKeyData
    specifier.setDescriptor(container, forKeyword: fourCharCode("from")) // keyAEContainer
    return specifier.coerce(toDescriptorType: fourCharCode("obj ")) ?? specifier // typeObjectSpecifier
}

private func fourCharCode(_ code: String) -> FourCharCode {
    code.utf8.reduce(0) { ($0 << 8) | FourCharCode($1) }
}

/// osascript is used instead of NSAppleScript because NSAppleScript blocks the main thread
private func setDockAutoHideViaOsascript(_ value: Bool) async -> SetDockAutoHideResult {
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
