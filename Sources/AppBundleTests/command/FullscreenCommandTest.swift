@testable import AppBundle
import Common
import XCTest

@MainActor
final class FullscreenCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseCommandSucc("fullscreen", FullscreenCmdArgs(rawArgs: []))
        testParseCommandSucc("fullscreen on", FullscreenCmdArgs(rawArgs: []).copy(\.toggle, .on))
        testParseCommandSucc("fullscreen off", FullscreenCmdArgs(rawArgs: []).copy(\.toggle, .off))

        testParseCommandSucc("fullscreen on --no-outer-gaps",
                             FullscreenCmdArgs(rawArgs: []).copy(\.toggle, .on).copy(\.noOuterGaps, true))
        testParseCommandSucc("fullscreen on --fail-if-noop",
                             FullscreenCmdArgs(rawArgs: []).copy(\.toggle, .on).copy(\.failIfNoop, true))
        testParseCommandSucc("fullscreen off --fail-if-noop",
                             FullscreenCmdArgs(rawArgs: []).copy(\.toggle, .off).copy(\.failIfNoop, true))
        testParseCommandSucc("fullscreen --window-id 42",
                             FullscreenCmdArgs(rawArgs: []).copy(\.windowId, 42))
        testParseCommandSucc("fullscreen --hide-others",
                             FullscreenCmdArgs(rawArgs: []).copy(\.hideOthers, true))
    }

    func testParseFullscreenCommandConflicts() {
        assertEquals(parseCommand("fullscreen off --no-outer-gaps").errorOrNil, "--no-outer-gaps is incompatible with 'off' argument")
        assertEquals(parseCommand("fullscreen --fail-if-noop").errorOrNil, "--fail-if-noop requires 'on' or 'off' argument")
    }
}
