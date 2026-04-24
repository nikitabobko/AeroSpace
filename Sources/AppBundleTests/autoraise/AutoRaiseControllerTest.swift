@testable import AppBundle
import Common
import XCTest

// State-machine coverage for AutoRaiseController. The eight scenarios here
// map 1:1 to autoraise-review-followups design.md §D2; each test is named
// after the transition it pins so a regression message says what broke.
//
// Scenarios 4 and 7 are the silent-regression hotspots:
//   - 4 is the whole point of the sticky flag (`runtimeDisabled`). If
//     `reload` ever stops respecting it, config file edits would silently
//     undo `disable-auto-raise`.
//   - 7 is the reason `reload` updates `masterPauseSnapshot` instead of
//     no-op'ing when paused. Without this, an `enable off` → TOML edit →
//     `enable on` sequence would resume with stale config.
@MainActor
final class AutoRaiseControllerTest: XCTestCase {
    private var fake: FakeAutoRaiseBridge!
    private var controller: AutoRaiseController!

    override func setUp() async throws {
        fake = FakeAutoRaiseBridge()
        controller = AutoRaiseController(bridge: fake)
    }

    // Scenario 1: cold start → bridge running, sticky flag cleared.
    func testStartFromCleanState() {
        _ = controller.start(config: .init(enabled: true, pollMillis: 8))
        assertEquals(fake.isRunning, true)
        assertEquals(controller.isNoopForDisableCommand, false)
        assertEquals(fake.calls, ["installRouteCallback", "start(enabled=true, pollMillis=8)"])
    }

    // Scenario 2: stop() sets the sticky flag AND stops the bridge.
    func testStopSetsStickyFlag() {
        _ = controller.start(config: .init(enabled: true))
        fake.calls.removeAll()

        controller.stop()

        assertEquals(fake.isRunning, false)
        assertEquals(controller.isNoopForDisableCommand, true)
        assertEquals(fake.calls, ["stop"])
    }

    // Scenario 3: start after stop clears the sticky flag.
    // The route callback is installed once per controller lifetime, so the
    // second start() does not re-install — expected sequence is just `start`.
    func testStartAfterStopClearsStickyFlag() {
        _ = controller.start(config: .init(enabled: true))
        controller.stop()
        assertEquals(controller.isNoopForDisableCommand, true)
        fake.calls.removeAll()

        _ = controller.start(config: .init(enabled: true, pollMillis: 16))

        assertEquals(fake.isRunning, true)
        assertEquals(controller.isNoopForDisableCommand, false)
        assertEquals(fake.calls, ["start(enabled=true, pollMillis=16)"])
    }

    // Scenario 4: reload respects sticky — bridge stays stopped.
    func testReloadRespectsSticky() {
        controller.stop() // sets sticky, bridge already stopped
        fake.calls.removeAll()

        controller.reload(config: .init(enabled: true, pollMillis: 32))

        assertEquals(fake.isRunning, false)
        assertEquals(fake.calls, []) // no bridge interaction at all
    }

    // Scenario 5: reload with config.enabled=false and not sticky → bridge stops.
    func testReloadStopsBridgeWhenConfigDisabled() {
        _ = controller.start(config: .init(enabled: true))
        fake.calls.removeAll()

        controller.reload(config: .init(enabled: false))

        assertEquals(fake.isRunning, false)
        assertEquals(fake.calls, ["stop"])
    }

    // Scenario 6: reload with config.enabled=true and not sticky → bridge starts
    // (or reloads if already running; this test covers the "starts" branch).
    func testReloadStartsBridgeWhenConfigEnabled() {
        // Clean slate: bridge stopped, not sticky.
        assertEquals(fake.isRunning, false)
        assertEquals(controller.isNoopForDisableCommand, false)

        controller.reload(config: .init(enabled: true, pollMillis: 8))

        assertEquals(fake.isRunning, true)
        assertEquals(fake.calls, ["installRouteCallback", "start(enabled=true, pollMillis=8)"])
    }

    // Scenario 6b: reload while already running → calls reload on the bridge,
    // not start. Pairs with 6 to pin both branches of the `enabled=true` path.
    func testReloadPassesThroughWhenAlreadyRunning() {
        _ = controller.start(config: .init(enabled: true, pollMillis: 8))
        fake.calls.removeAll()

        controller.reload(config: .init(enabled: true, pollMillis: 32))

        assertEquals(fake.isRunning, true)
        assertEquals(fake.calls, ["reload(enabled=true, pollMillis=32)"])
    }

    // Scenario 7: pause → reload(newConfig) → resume — resume carries the NEW
    // config, not the pre-pause one. This is the whole reason reload()
    // updates masterPauseSnapshot instead of no-op'ing while paused.
    func testReloadDuringMasterPauseUpdatesSnapshot() {
        _ = controller.start(config: .init(enabled: true, pollMillis: 8))
        controller.pauseForMaster()
        assertEquals(fake.isRunning, false) // paused
        fake.calls.removeAll()

        // While paused, config changes.
        controller.reload(config: .init(enabled: true, pollMillis: 64))
        assertEquals(fake.isRunning, false) // still paused — reload doesn't restart
        assertEquals(fake.calls, []) // no bridge calls during pause-reload

        controller.resumeFromMaster()

        assertEquals(fake.isRunning, true)
        // The post-resume start carries pollMillis=64 (the reloaded value),
        // not pollMillis=8 (the pre-pause value).
        assertEquals(fake.calls, ["start(enabled=true, pollMillis=64)"])
    }

    // Scenario 8: pause → sticky-disable mid-pause → resume is a no-op.
    // The master-pause path must not re-enable a user-disabled bridge.
    func testResumeFromMasterRespectsSticky() {
        _ = controller.start(config: .init(enabled: true))
        controller.pauseForMaster()
        controller.stop() // sticky-disable while paused
        assertEquals(controller.isNoopForDisableCommand, true)
        fake.calls.removeAll()

        controller.resumeFromMaster()

        assertEquals(fake.isRunning, false)
        assertEquals(controller.isNoopForDisableCommand, true)
        assertEquals(fake.calls, []) // resumeFromMaster is a full no-op here
    }

    // Edge case: start() fails (event-tap install rejected). Sticky flag
    // must be cleared on the *attempt*, not gated on success — matches the
    // current implementation where runtimeDisabled=false is set before the
    // bridge call. Pinning this so a future refactor doesn't invert the
    // order and strand users in sticky-disabled state after a failed start.
    func testStartFailureClearsStickyFlag() {
        controller.stop() // sticky-disable first
        assertEquals(controller.isNoopForDisableCommand, true)
        fake.startShouldFail = true
        fake.calls.removeAll()

        let ok = controller.start(config: .init(enabled: true))

        assertEquals(ok, false)
        assertEquals(fake.isRunning, false)
        // Sticky flag was cleared by the start() attempt; bridge is just off
        // because the tap failed. isNoopForDisableCommand reports the AND of
        // (!isEnabled && runtimeDisabled), which is now false.
        assertEquals(controller.isNoopForDisableCommand, false)
        assertEquals(fake.calls, ["installRouteCallback", "start(enabled=true, pollMillis=8)"])
    }
}
