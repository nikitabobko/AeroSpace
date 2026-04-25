@testable import AppBundle
import Common
import XCTest

@MainActor
final class ParseDwindleTest: XCTestCase {
    func testDefaults() {
        let (config, errors) = parseConfig("")
        assertEquals(errors, [])
        assertEquals(config.dwindle, DwindleConfig())
        assertEquals(config.dwindle.forceSplit, .auto)
        assertEquals(config.dwindle.smartSplit, false)
        assertEquals(config.dwindle.preserveSplit, false)
        assertEquals(config.dwindle.defaultSplitRatio, 0.5)
        assertEquals(config.dwindle.splitWidthMultiplier, 1.0)
        assertEquals(config.dwindle.noGapsWhenOnly, false)
        assertEquals(config.dwindle.useActiveForSplits, true)
    }

    func testFullRoundTrip() {
        let (config, errors) = parseConfig(
            """
            [dwindle]
                force-split = 'first'
                smart-split = true
                preserve-split = true
                default-split-ratio = 0.6
                split-width-multiplier = 1.4
                no-gaps-when-only = true
                use-active-for-splits = false
            """,
        )
        assertEquals(errors, [])
        assertEquals(config.dwindle.forceSplit, .first)
        assertEquals(config.dwindle.smartSplit, true)
        assertEquals(config.dwindle.preserveSplit, true)
        assertEquals(config.dwindle.defaultSplitRatio, 0.6)
        assertEquals(config.dwindle.splitWidthMultiplier, 1.4)
        assertEquals(config.dwindle.noGapsWhenOnly, true)
        assertEquals(config.dwindle.useActiveForSplits, false)
    }

    func testInvalidForceSplit() {
        let (_, errors) = parseConfig(
            """
            [dwindle]
                force-split = 'invalid'
            """,
        )
        assertEquals(errors, ["dwindle.force-split: Can't parse force-split 'invalid'. Allowed values: auto, first, second"])
    }

    func testRatioOutOfRange_zero() {
        let (_, errors) = parseConfig(
            """
            [dwindle]
                default-split-ratio = 0.0
            """,
        )
        assertEquals(errors, ["dwindle.default-split-ratio: default-split-ratio must be in the open interval (0.0, 1.0)"])
    }

    func testRatioOutOfRange_one() {
        let (_, errors) = parseConfig(
            """
            [dwindle]
                default-split-ratio = 1.0
            """,
        )
        assertEquals(errors, ["dwindle.default-split-ratio: default-split-ratio must be in the open interval (0.0, 1.0)"])
    }

    func testRatioOutOfRange_negative() {
        let (_, errors) = parseConfig(
            """
            [dwindle]
                default-split-ratio = -0.1
            """,
        )
        assertEquals(errors, ["dwindle.default-split-ratio: default-split-ratio must be in the open interval (0.0, 1.0)"])
    }

    func testMultiplierZeroRejected() {
        let (_, errors) = parseConfig(
            """
            [dwindle]
                split-width-multiplier = 0.0
            """,
        )
        assertEquals(errors, ["dwindle.split-width-multiplier: split-width-multiplier must be > 0"])
    }

    func testMultiplierNegativeRejected() {
        let (_, errors) = parseConfig(
            """
            [dwindle]
                split-width-multiplier = -0.5
            """,
        )
        assertEquals(errors, ["dwindle.split-width-multiplier: split-width-multiplier must be > 0"])
    }

    func testIntegerAcceptedForFloatField() {
        // TOML's `1` decodes as Int but is a perfectly valid value for a float
        // field. `parseDouble` widens int → double transparently.
        let (config, errors) = parseConfig(
            """
            [dwindle]
                split-width-multiplier = 1
            """,
        )
        assertEquals(errors, [])
        assertEquals(config.dwindle.splitWidthMultiplier, 1.0)
    }

    func testUnknownKeyRejected() {
        let (_, errors) = parseConfig(
            """
            [dwindle]
                bogus-key = true
            """,
        )
        assertEquals(errors, ["dwindle.bogus-key: Unknown key"])
    }
}
