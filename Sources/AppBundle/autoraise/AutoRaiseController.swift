import AppKit
import AutoRaiseCore
import Common

// Owns the AutoRaiseCore lifecycle (design.md §D4) and reconciles four state
// sources: the TOML `[auto-raise]` section (startup + file-watcher reloads),
// the runtime toggle commands (enable-auto-raise / disable-auto-raise), the
// master `enable on/off` toggle (via pauseForMaster / resumeFromMaster), and
// the macOS NSWorkspace observer hooks fanned out from GlobalObserver.
//
// Precedence rules:
//   - Runtime disable is sticky across config reloads (§D8). Once the user
//     runs `disable-auto-raise`, touching the config file does not silently
//     re-enable hover-raise. Running `enable-auto-raise` clears the flag.
//   - The master toggle takes effect independently: `enable off` stops the
//     bridge and snapshots the running state; `enable on` restores it. The
//     snapshot is NOT sticky — it's only consulted across a single
//     off→on cycle.
//
// The class has a `shared` singleton used by production call sites via
// static forwarders below. Tests instantiate a fresh controller with a
// `FakeAutoRaiseBridge` to exercise the state machine without touching the
// real CGEventTap. See openspec change autoraise-review-followups §D3.
@MainActor
final class AutoRaiseController {
    static let shared = AutoRaiseController()

    private let bridge: AutoRaiseBridgeProtocol
    private var lastConfig: AutoRaiseConfig?
    private var runtimeDisabled: Bool = false
    private var routeCallbackInstalled: Bool = false
    // Non-nil while the bridge is paused by `enable off`. Carries the config
    // that was in effect at pause time so `enable on` can restart cleanly.
    private var masterPauseSnapshot: AutoRaiseConfig?

    init(bridge: AutoRaiseBridgeProtocol = LiveAutoRaiseBridge()) {
        self.bridge = bridge
    }

    var isEnabled: Bool { bridge.isRunning }

    // True when `disable-auto-raise` has disabled the bridge AND the bridge
    // is currently not running. Used by `disable-auto-raise` to detect true
    // no-op invocations (already stopped AND sticky flag set).
    var isNoopForDisableCommand: Bool { !isEnabled && runtimeDisabled }

    // User-triggered start — called at boot (gated on config.enabled) and by
    // `enable-auto-raise`. Ignores config.enabled at this layer: the caller
    // decided to start, we start. Clears the sticky runtime-disabled flag.
    // Returns true iff the bridge is running after the call — false means the
    // tap could not be installed (typically: Accessibility permission missing).
    @discardableResult
    func start(config: AutoRaiseConfig) -> Bool {
        runtimeDisabled = false
        lastConfig = config
        installRouteCallbackOnce()
        if bridge.isRunning {
            bridge.reload(config)
            return true
        }
        return bridge.start(config)
    }

    // User-triggered stop — `disable-auto-raise`. Sets the sticky flag so a
    // subsequent config reload doesn't silently re-enable.
    func stop() {
        runtimeDisabled = true
        if bridge.isRunning { bridge.stop() }
    }

    // Config-file-watcher reload. Respects the sticky runtime-disabled flag;
    // otherwise mirrors start/stop based on config.enabled.
    func reload(config: AutoRaiseConfig) {
        lastConfig = config
        if runtimeDisabled { return }
        if masterPauseSnapshot != nil {
            // Paused by `enable off`. Update the snapshot so the eventual
            // `enable on` resumes with the newest config, but don't restart
            // the bridge here.
            masterPauseSnapshot = config
            return
        }
        if config.enabled {
            installRouteCallbackOnce()
            if bridge.isRunning {
                bridge.reload(config)
            } else {
                _ = bridge.start(config)
            }
        } else {
            if bridge.isRunning { bridge.stop() }
        }
    }

    // Called by EnableCommand when the master toggle flips to off. Snapshots
    // the currently-applied config (if the bridge was running) so the
    // corresponding `enable on` can restart with it. Does NOT mutate
    // runtimeDisabled — a user-level disable survives a master-off/on cycle.
    func pauseForMaster() {
        guard bridge.isRunning, let config = lastConfig else { return }
        masterPauseSnapshot = config
        bridge.stop()
    }

    // Called by EnableCommand when the master toggle flips to on. If a
    // snapshot is pending AND the user hasn't sticky-disabled, restart.
    func resumeFromMaster() {
        guard let config = masterPauseSnapshot else { return }
        masterPauseSnapshot = nil
        if runtimeDisabled { return }
        installRouteCallbackOnce()
        _ = bridge.start(config)
    }

    // Fanned out from GlobalObserver (design.md §D6).
    func onActiveSpaceDidChange() { bridge.onActiveSpaceDidChange() }
    func onAppDidActivate() { bridge.onAppDidActivate() }

    // Called at the end of runLightSession. AeroSpace's own commands can pull
    // the window out from under the cursor (move-node-to-workspace, close,
    // layout, flatten-workspace-tree, …) without a macOS-level space change,
    // so the mouse-event-driven auto-raise path never fires.
    //
    // We deliberately skip AutoRaiseCore's hit-test here. layoutWorkspaces
    // sets window frames via AXUIElementSetAttributeValue, which propagates
    // to each target app's AX server asynchronously — an immediate AX
    // hit-test races with that round-trip. AeroSpace just wrote the layout
    // itself, so `lastAppliedLayoutPhysicalRect` is the authoritative source
    // for "where is window X on screen right now". Walk the focused
    // workspace's tree instead and route directly.
    func onLayoutDidChange() {
        guard isEnabled else { return }
        let cursor = CGEvent(source: nil)?.location ?? .zero
        guard let window = Self.findWindowUnderCursor(
            cursor: cursor,
            workspace: focus.workspace,
        ) else { return }
        RaiseRouter.route(windowId: CGWindowID(window.windowId))
    }

    // Pure helper: given a cursor point and a workspace, find the leaf window
    // whose last-applied layout rect contains the cursor. Extracted from
    // onLayoutDidChange for testability (no CGEvent / focus-globals
    // dependency). Windows without a `lastAppliedLayoutPhysicalRect` (never
    // laid out) are skipped — the missing rect means AeroSpace hasn't
    // positioned the window, so we can't claim the cursor is "over" it.
    static func findWindowUnderCursor(cursor: CGPoint, workspace: Workspace) -> Window? {
        workspace.allLeafWindowsRecursive.first(where: {
            $0.lastAppliedLayoutPhysicalRect?.contains(cursor) == true
        })
    }

    private func installRouteCallbackOnce() {
        if routeCallbackInstalled { return }
        bridge.installRouteCallback()
        routeCallbackInstalled = true
    }

    // --- Static forwarders ------------------------------------------------
    // Production call sites (GlobalObserver, EnableCommand, ReloadConfigCommand,
    // EnableAutoRaiseCommand, DisableAutoRaiseCommand, initAppBundle.swift,
    // refresh.swift) stay pointed at `AutoRaiseController.xxx`; each shim
    // forwards to `shared`. Tests bypass these and call instance methods
    // on a test-owned controller directly.

    static var isEnabled: Bool { shared.isEnabled }
    static var isNoopForDisableCommand: Bool { shared.isNoopForDisableCommand }

    @discardableResult
    static func start(config: AutoRaiseConfig) -> Bool { shared.start(config: config) }
    static func stop() { shared.stop() }
    static func reload(config: AutoRaiseConfig) { shared.reload(config: config) }
    static func pauseForMaster() { shared.pauseForMaster() }
    static func resumeFromMaster() { shared.resumeFromMaster() }
    static func onActiveSpaceDidChange() { shared.onActiveSpaceDidChange() }
    static func onAppDidActivate() { shared.onAppDidActivate() }
    static func onLayoutDidChange() { shared.onLayoutDidChange() }
}
