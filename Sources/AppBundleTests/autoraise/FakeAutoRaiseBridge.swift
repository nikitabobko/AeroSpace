@testable import AppBundle
import AppKit

// Test double for AutoRaiseBridgeProtocol. Records every call in `calls` and
// exposes `isRunning` as a public settable flag so tests can assert the
// controller's bridge-interaction sequence without installing a real
// CGEventTap. See autoraise-review-followups design.md §D3.
@MainActor
final class FakeAutoRaiseBridge: AutoRaiseBridgeProtocol {
    var isRunning: Bool = false
    // When true, `start(_:)` returns false without flipping `isRunning`.
    // Simulates CGEventTapCreate failing (typically: missing Accessibility
    // permission on the real machine).
    var startShouldFail: Bool = false
    var calls: [String] = []

    @discardableResult
    func start(_ config: AutoRaiseConfig) -> Bool {
        calls.append("start(enabled=\(config.enabled), pollMillis=\(config.pollMillis))")
        if startShouldFail { return false }
        isRunning = true
        return true
    }

    func stop() {
        calls.append("stop")
        isRunning = false
    }

    func reload(_ config: AutoRaiseConfig) {
        calls.append("reload(enabled=\(config.enabled), pollMillis=\(config.pollMillis))")
    }

    func installRouteCallback() {
        calls.append("installRouteCallback")
    }

    func onActiveSpaceDidChange() {
        calls.append("onActiveSpaceDidChange")
    }

    func onAppDidActivate() {
        calls.append("onAppDidActivate")
    }
}
