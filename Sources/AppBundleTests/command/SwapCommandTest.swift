@testable import AppBundle
import Common
import XCTest

@MainActor
final class SwapCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSwap_swapWindows_Directional() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
                TestWindow.new(id: 2, parent: $0)
            }
            TestWindow.new(id: 3, parent: $0)
        }

        await parseCommand("swap right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(3), .window(2)]),
                               .window(1)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(root.mostRecentWindowRecursive?.windowId, 1)

        await parseCommand("swap left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(1), .window(2)]),
                               .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(root.mostRecentWindowRecursive?.windowId, 1)

        await parseCommand("swap down").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(2), .window(1)]),
                               .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(root.mostRecentWindowRecursive?.windowId, 1)

        await parseCommand("swap up").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(1), .window(2)]),
                               .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(root.mostRecentWindowRecursive?.windowId, 1)
    }

    func testSwap_swapWindows_DfsRelative() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
                TestWindow.new(id: 2, parent: $0)
            }
            TestWindow.new(id: 3, parent: $0)
        }

        await parseCommand("swap dfs-next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(2), .window(1)]),
                               .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(root.mostRecentWindowRecursive?.windowId, 1)

        await parseCommand("swap dfs-next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(2), .window(3)]),
                               .window(1)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(root.mostRecentWindowRecursive?.windowId, 1)

        await parseCommand("swap dfs-prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(2), .window(1)]),
                               .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(root.mostRecentWindowRecursive?.windowId, 1)

        await parseCommand("swap dfs-prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(1), .window(2)]),
                               .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(root.mostRecentWindowRecursive?.windowId, 1)
    }

    func testSwap_DirectionalWrapping() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }

        await parseCommand("swap --wrap-around left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(3), .window(2), .window(1)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(root.mostRecentWindowRecursive?.windowId, 1)

        await parseCommand("swap --wrap-around right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2), .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(root.mostRecentWindowRecursive?.windowId, 1)
    }

    func testSwap_DfsRelativeWrapping() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }

        await parseCommand("swap --wrap-around dfs-prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(3), .window(2), .window(1)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(root.mostRecentWindowRecursive?.windowId, 1)

        await parseCommand("swap --wrap-around dfs-next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2), .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(root.mostRecentWindowRecursive?.windowId, 1)
    }

    func testSwap_SwapFocus() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }

        await parseCommand("swap --swap-focus right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(3), .window(2)]))
        assertEquals(focus.windowOrNil?.windowId, 3)
        assertEquals(root.mostRecentWindowRecursive?.windowId, 3)
    }
}
