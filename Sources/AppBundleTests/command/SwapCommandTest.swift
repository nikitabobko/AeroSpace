@testable import AppBundle
import Common
import XCTest

@MainActor
final class SwapCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSwap_swapWindows_Directional() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
                TestWindow.new(id: 2, parent: $0)
            }
            TestWindow.new(id: 3, parent: $0)
        }

        SwapCommand(args: SwapCmdArgs(rawArgs: [], target: .direction(.right))).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(3), .window(2)]),
                               .window(1)]))
        assertEquals(focus.windowOrNil?.windowId, 1)

        SwapCommand(args: SwapCmdArgs(rawArgs: [], target: .direction(.left))).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(1), .window(2)]),
                               .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)

        SwapCommand(args: SwapCmdArgs(rawArgs: [], target: .direction(.down))).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(2), .window(1)]),
                               .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)

        SwapCommand(args: SwapCmdArgs(rawArgs: [], target: .direction(.up))).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(1), .window(2)]),
                               .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testSwap_swapWindows_DfsRelative() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
                TestWindow.new(id: 2, parent: $0)
            }
            TestWindow.new(id: 3, parent: $0)
        }

        SwapCommand(args: SwapCmdArgs(rawArgs: [], target: .dfsRelative(.next))).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(2), .window(1)]),
                               .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)

        SwapCommand(args: SwapCmdArgs(rawArgs: [], target: .dfsRelative(.next))).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(2), .window(3)]),
                               .window(1)]))
        assertEquals(focus.windowOrNil?.windowId, 1)

        SwapCommand(args: SwapCmdArgs(rawArgs: [], target: .dfsRelative(.prev))).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(2), .window(1)]),
                               .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)

        SwapCommand(args: SwapCmdArgs(rawArgs: [], target: .dfsRelative(.prev))).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(1), .window(2)]),
                               .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testSwap_DirectionalWrapping() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }

        var args = SwapCmdArgs(rawArgs: [], target: .direction(.left))
        args.wrapAround = true
        SwapCommand(args: args).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(3), .window(2), .window(1)]))
        assertEquals(focus.windowOrNil?.windowId, 1)

        args.target = .initialized(.direction(.right))
        SwapCommand(args: args).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2), .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testSwap_DfsRelativeWrapping() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }

        var args = SwapCmdArgs(rawArgs: [], target: .dfsRelative(.prev))
        args.wrapAround = true
        SwapCommand(args: args).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(3), .window(2), .window(1)]))
        assertEquals(focus.windowOrNil?.windowId, 1)

        args.target = .initialized(.dfsRelative(.next))
        SwapCommand(args: args).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2), .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testSwap_SwapFocus() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }

        var args = SwapCmdArgs(rawArgs: [], target: .direction(.right))
        args.swapFocus = true
        SwapCommand(args: args).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(3), .window(2)]))
        assertEquals(focus.windowOrNil?.windowId, 3)
    }
}
