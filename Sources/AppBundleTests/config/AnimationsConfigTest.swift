@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct AnimationsConfigTest {
    @Test func testDefaultsWhenAbsent() {
        let result = parseConfig("")
        assertEquals(result.errors, [])
        assertEquals(result.config.animations, AnimationsConfig())
        assertEquals(result.config.animations.resizeDurationMs, 0)
        assertEquals(result.config.animations.fullscreenDurationMs, 0)
        assertEquals(result.config.animations.workspaceSlideDurationMs, 0)
        assertEquals(result.config.animations.easing, .easeOut)
    }

    @Test func testDefaultConfigDisablesAnimations() {
        assertEquals(defaultConfig.animations, AnimationsConfig())
    }

    @Test func testValidValues() {
        let result = parseConfig(
            """
            [animations]
                resize-duration-ms = 150
                fullscreen-duration-ms = 200
                workspace-slide-duration-ms = 250
                easing = 'ease-in-out'
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(
            result.config.animations,
            AnimationsConfig(resizeDurationMs: 150, fullscreenDurationMs: 200, workspaceSlideDurationMs: 250, easing: .easeInOut),
        )
    }

    @Test func testAllEasings() {
        for easing in Easing.allCases {
            let result = parseConfig(
                """
                [animations]
                    easing = '\(easing.rawValue)'
                """,
            )
            assertEquals(result.errors, [])
            assertEquals(result.config.animations.easing, easing)
        }
    }

    @Test func testRangeBoundaries() {
        let result = parseConfig(
            """
            [animations]
                resize-duration-ms = 0
                fullscreen-duration-ms = 1000
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.config.animations.resizeDurationMs, 0)
        assertEquals(result.config.animations.fullscreenDurationMs, 1000)
    }

    @Test func testOutOfRange() {
        let result = parseConfig(
            """
            [animations]
                resize-duration-ms = -1
                fullscreen-duration-ms = 1001
                workspace-slide-duration-ms = 250
            """,
        )
        assertEquals(result.strErrors.sorted(), [
            "[ERROR] animations.fullscreen-duration-ms: Animation duration must be in [0, 1000] range (milliseconds). But got: 1001",
            "[ERROR] animations.resize-duration-ms: Animation duration must be in [0, 1000] range (milliseconds). But got: -1",
        ])
        assertEquals(result.config.animations.resizeDurationMs, 0)
        assertEquals(result.config.animations.fullscreenDurationMs, 0)
        assertEquals(result.config.animations.workspaceSlideDurationMs, 250)
    }

    @Test func testWrongType() {
        let result = parseConfig(
            """
            [animations]
                resize-duration-ms = '150'
                easing = 1
            """,
        )
        assertEquals(result.strErrors.sorted(), [
            "[ERROR] animations.easing: Expected type is 'String'. But actual type is 'Int'",
            "[ERROR] animations.resize-duration-ms: Expected type is 'Int'. But actual type is 'String'",
        ])
        assertEquals(result.config.animations, AnimationsConfig())
    }

    @Test func testAnimationsMustBeTable() {
        let result = parseConfig(
            """
            animations = 150
            """,
        )
        assertEquals(result.strErrors, ["[ERROR] animations: Expected type is 'Table'. But actual type is 'Int'"])
    }

    @Test func testUnknownEasing() {
        let result = parseConfig(
            """
            [animations]
                easing = 'bounce'
            """,
        )
        assertEquals(result.strErrors, [
            "[ERROR] animations.easing: Can't parse easing 'bounce'. Possible values: linear, ease-out, ease-in-out",
        ])
        assertEquals(result.config.animations.easing, .easeOut)
    }

    @Test func testUnknownKey() {
        let result = parseConfig(
            """
            [animations]
                resize-duration-ms = 100
                bounce-duration-ms = 100
            """,
        )
        assertEquals(result.strErrors, ["[ERROR] animations.bounce-duration-ms: Unknown key"])
        assertEquals(result.config.animations.resizeDurationMs, 100)
    }

    @Test func testDefaultConfigFileParsesAnimationsBlock() {
        let toml = try! String(contentsOf: projectRoot.appending(component: "docs/config-examples/default-config.toml"), encoding: .utf8)
        assertTrue(toml.contains("[animations]"))
        let result = parseConfig(toml)
        assertEquals(result.errors, [])
        assertEquals(result.config.animations, AnimationsConfig())
    }

    @Test func testEmptyAnimationsTable() {
        let result = parseConfig(
            """
            [animations]
            """,
        )
        assertEquals(result.strErrors, ["[ERROR] animations: empty table is not allowed here"])
        assertEquals(result.config.animations, AnimationsConfig())
    }

    @Test func testLongIntegerOverflowIsRejected() {
        let result = parseConfig(
            """
            [animations]
                resize-duration-ms = 9999999999
            """,
        )
        assertEquals(result.errors.count, 1)
        assertEquals(result.config.animations.resizeDurationMs, 0)
    }
}
