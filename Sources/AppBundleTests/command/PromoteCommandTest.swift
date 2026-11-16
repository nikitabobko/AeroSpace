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

    @Test func testPromoteFailsForFloatingWindowWithoutTilingWindows() async {
        Workspace.get(byName: name).apply {
            assertEquals(TestWindow.new(id: 1, parent: $0.floatingWindowsContainer).focusWindow(), true)
        }

        let result = await parseCommand("promote").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, .fail)
    }

    @Test func testPromoteOnAccordionWorkspace() async {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                $0.layout = .accordion
                TestWindow.new(id: 1, parent: $0)
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            }
        }

        await parseCommand("promote").cmdOrDie.run(.defaultEnv, .emptyStdin)
        // The master is the first window in the visual order
        assertEquals(workspace.layoutDescription, .workspace([
            .h_accordion([.window(2), .window(1)]),
        ]))
    }

    @Test func testPromoteSwapsWithSkeletonMasterOnTheRight() async {
        config.workspaceLayout = [name: parse("h_tiles[v_tiles[others], 1]")]
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                    assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
                    TestWindow.new(id: 2, parent: $0)
                }
                TestWindow.new(id: 3, parent: $0) // The master: placeholder slot 1 is on the right
            }
        }

        await parseCommand("promote").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(workspace.layoutDescription, .workspace([
            .h_tiles([.v_tiles([.window(3), .window(2)]), .window(1)]),
        ]))
        assertEquals(globalFocus.windowOrNil?.windowId, 1)
    }

    @Test func testPromoteTargetsWorkspaceViaFlag() async {
        let workspace = Workspace.get(byName: "ws").apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            }
        }

        let result = await parseCommand("promote --workspace ws").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(workspace.layoutDescription, .workspace([
            .h_tiles([.window(2), .window(1)]),
        ]))
    }

    private func parse(_ source: String) -> LayoutSkeleton {
        switch LayoutSkeleton.parse(source) {
            case .success(let skeleton): return skeleton
            case .failure(let error): fatalError("Can't parse '\(source)': \(error.description)")
        }
    }
}
