@testable import AppBundle
import Common
import XCTest

@MainActor
final class ParseAutoRaiseTest: XCTestCase {
    func testDefaults() {
        let (config, errors) = parseConfig("")
        assertEquals(errors, [])
        assertEquals(config.autoRaise, AutoRaiseConfig())
        assertEquals(config.autoRaise.enabled, false)
        assertEquals(config.autoRaise.pollMillis, 8)
        assertEquals(config.autoRaise.disableKey, .control)
    }

    func testFullRoundTrip() {
        let (config, errors) = parseConfig(
            """
            [auto-raise]
                enabled = true
                poll-millis = 16
                ignore-space-changed = true
                invert-disable-key = true
                invert-ignore-apps = true
                ignore-apps = ["Finder", "Safari"]
                ignore-titles = ["^Picture-in-Picture$", "window$"]
                stay-focused-bundle-ids = ["com.apple.SecurityAgent"]
                disable-key = "option"
            """,
        )
        assertEquals(errors, [])
        assertEquals(config.autoRaise.enabled, true)
        assertEquals(config.autoRaise.pollMillis, 16)
        assertEquals(config.autoRaise.ignoreSpaceChanged, true)
        assertEquals(config.autoRaise.invertDisableKey, true)
        assertEquals(config.autoRaise.invertIgnoreApps, true)
        assertEquals(config.autoRaise.ignoreApps, ["Finder", "Safari"])
        assertEquals(config.autoRaise.ignoreTitles, ["^Picture-in-Picture$", "window$"])
        assertEquals(config.autoRaise.stayFocusedBundleIds, ["com.apple.SecurityAgent"])
        assertEquals(config.autoRaise.disableKey, .option)
    }

    func testPollMillisMinimum() {
        let (_, errors) = parseConfig(
            """
            [auto-raise]
                poll-millis = 0
            """,
        )
        assertEquals(errors, ["auto-raise.poll-millis: Must be >= 1"])
    }

    func testInvalidDisableKey() {
        let (_, errors) = parseConfig(
            """
            [auto-raise]
                disable-key = "shift"
            """,
        )
        assertEquals(errors, ["auto-raise.disable-key: Can't parse disable-key 'shift'. Allowed values: control, option, disabled"])
    }

    func testDisableKeyDisabledIsAllowed() {
        let (config, errors) = parseConfig(
            """
            [auto-raise]
                disable-key = "disabled"
            """,
        )
        assertEquals(errors, [])
        assertEquals(config.autoRaise.disableKey, .disabled)
    }

    func testInvalidIgnoreTitlesRegex() {
        let (_, errors) = parseConfig(
            """
            [auto-raise]
                ignore-titles = ["valid", "[unclosed"]
            """,
        )
        // Pattern index 1 is the bad one; the prefix is deterministic, the
        // localized suffix is not.
        assertEquals(errors.count, 1)
        XCTAssertTrue(errors[0].hasPrefix("auto-raise.ignore-titles[1]: Invalid regex '[unclosed': "))
    }

    // Upstream AutoRaise warp-related keys (warpX/warpY/scale/altTaskSwitcher)
    // must be rejected — see spec "Upstream warp keys are rejected". Using an
    // integer value here so the parser surfaces the unknown-key error rather
    // than the "Unsupported TOML type: Double" error it would raise for 0.5.
    func testUnknownKeyRejected() {
        let (_, errors) = parseConfig(
            """
            [auto-raise]
                altTaskSwitcher = true
            """,
        )
        assertEquals(errors, ["auto-raise.altTaskSwitcher: Unknown key"])
    }
}
