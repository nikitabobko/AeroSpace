import AppKit
import AutoRaiseCore
import Common

// Seam between AutoRaiseController and AutoRaiseCore's C bridge. Production
// code uses LiveAutoRaiseBridge, which forwards 1:1 to the C API. Tests swap
// in a fake so the controller's state-machine logic can be exercised without
// installing a real CGEventTap.
//
// Rationale: see openspec change autoraise-review-followups (design.md §D3).
// The controller reconciles four state sources (config, runtime toggle,
// master enable, NSWorkspace observers); each transition needs to be covered
// by unit tests to catch silent regressions (e.g. start() forgetting to
// clear the sticky flag, or resumeFromMaster ignoring sticky state). None
// of that logic touches the C bridge's internals — only its observable
// surface — so a protocol is the right seam.
@MainActor
protocol AutoRaiseBridgeProtocol {
    var isRunning: Bool { get }
    @discardableResult func start(_ config: AutoRaiseConfig) -> Bool
    func stop()
    func reload(_ config: AutoRaiseConfig)
    func installRouteCallback()
    func onActiveSpaceDidChange()
    func onAppDidActivate()
}

// Production conformance. Each method is a straight delegate to the C API
// declared in AutoRaiseCore/include/AutoRaiseBridge.h. AutoRaiseConfig is
// converted to the ObjC AutoRaiseBridgeConfig here so call sites (and the
// test fake) never deal with the ObjC type.
@MainActor
struct LiveAutoRaiseBridge: AutoRaiseBridgeProtocol {
    var isRunning: Bool { autoraise_is_running() }

    @discardableResult func start(_ config: AutoRaiseConfig) -> Bool {
        autoraise_start(config.toBridge())
    }

    func stop() { autoraise_stop() }

    func reload(_ config: AutoRaiseConfig) { autoraise_reload(config.toBridge()) }

    func installRouteCallback() { autoraise_set_route_callback(RaiseRouter.cCallback) }

    func onActiveSpaceDidChange() { autoraise_on_active_space_did_change() }

    func onAppDidActivate() { autoraise_on_app_did_activate() }
}
