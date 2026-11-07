@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct FullscreenCommandTest {
    init() { setUpWorkspacesForTests() }

    @Test func testTogglingMarksPendingFullscreenTransition() async {
        var window: Window! = nil
        Workspace.get(byName: name).rootTilingContainer.apply {
            window = TestWindow.new(id: 1, parent: $0)
            assertEquals(window.focusWindow(), true)
        }
        assertFalse(window.pendingFullscreenTransition)

        await parseCommand("fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertTrue(window.isFullscreen)
        assertTrue(window.consumePendingFullscreenTransition())
        assertFalse(window.consumePendingFullscreenTransition())

        await parseCommand("fullscreen off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertFalse(window.isFullscreen)
        assertTrue(window.consumePendingFullscreenTransition())
    }

    @Test func testNoopDoesNotMarkPendingFullscreenTransition() async {
        var window: Window! = nil
        Workspace.get(byName: name).rootTilingContainer.apply {
            window = TestWindow.new(id: 1, parent: $0)
            assertEquals(window.focusWindow(), true)
        }

        await parseCommand("fullscreen off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertFalse(window.pendingFullscreenTransition)
    }
}
