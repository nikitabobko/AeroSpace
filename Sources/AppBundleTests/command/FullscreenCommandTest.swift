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

    func testFullscreenCommandHideOthers() async throws {
        let workspace = Workspace.get(byName: name)
        let focusedWindow = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let otherWindow1 = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        let otherWindow2 = TestWindow.new(id: 3, parent: workspace.rootTilingContainer)

        _ = focusedWindow.focusWindow()

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(workspace.rootTilingContainer.children.count, 3)
        assertEquals(focusedWindow.isFullscreen, false)
        assertEquals(focusedWindow.shouldHideOthersWhileFullscreen, false)
        assertEquals(otherWindow1.isHiddenInCorner, false)
        assertEquals(otherWindow2.isHiddenInCorner, false)

        let result = try await parseCommand("fullscreen --hide-others").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(focusedWindow.isFullscreen, true)
        assertEquals(focusedWindow.shouldHideOthersWhileFullscreen, true)
        assertEquals(otherWindow1.isHiddenInCorner, true)
        assertEquals(otherWindow2.isHiddenInCorner, true)

        let secondResult = try await parseCommand("fullscreen off").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(secondResult.exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(focusedWindow.isFullscreen, false)
        assertEquals(focusedWindow.shouldHideOthersWhileFullscreen, false)
        assertEquals(otherWindow1.isHiddenInCorner, false)
        assertEquals(otherWindow2.isHiddenInCorner, false)
    }
}
