@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct PromoteCommandTest {
    init() { setUpWorkspacesForTests() }

    @Test func testPromoteSwapsFocusedWindowWithMaster() async {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
                TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 2, parent: $0)
                    assertEquals(TestWindow.new(id: 3, parent: $0).focusWindow(), true)
                }
            }
        }

        await parseCommand("promote").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(workspace.layoutDescription, .workspace([
            .h_tiles([.window(3), .v_tiles([.window(2), .window(1)])]),
        ]))
        assertEquals(globalFocus.windowOrNil?.windowId, 3)
    }

    @Test func testPromoteIsNoopWhenMasterIsFocused() async {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
                TestWindow.new(id: 2, parent: $0)
            }
        }

        await parseCommand("promote").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(workspace.layoutDescription, .workspace([.h_tiles([.window(1), .window(2)])]))
        assertEquals(globalFocus.windowOrNil?.windowId, 1)
    }

    @Test func testPromoteFailsForFloatingWindow() async {
        Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
            }
            assertEquals(TestWindow.new(id: 2, parent: $0.floatingWindowsContainer).focusWindow(), true)
        }

        let result = await parseCommand("promote").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, .fail)
    }
}
