@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct SwapWorkspacesCommandTest {
    init() { setUpWorkspacesForTests() }

    @Test func testParse() {
        assertEquals(parseCommand("swap-workspaces").errorOrNil, "ERROR: Argument '<workspace-a>' is mandatory\nERROR: Argument '<workspace-b>' is mandatory")
        assertEquals(parseCommand("swap-workspaces 1").errorOrNil, "ERROR: Argument '<workspace-b>' is mandatory")
        assertNil(parseCommand("swap-workspaces 1 2").errorOrNil)
        assertNil(parseCommand("swap-workspaces -- 1 2").errorOrNil)
        assertEquals(parseCommand("swap-workspaces 1 2 3").errorOrNil, "ERROR: Unknown argument '3'")
    }

    @Test func testSwapMovesLayoutsAndKeepsTheFocusedWorkspace() async {
        let a = Workspace.get(byName: "a")
        let b = Workspace.get(byName: "b")
        a.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 2, parent: $0)
                TestWindow.new(id: 3, parent: $0)
            }
        }
        TestWindow.new(id: 4, parent: a.floatingWindowsContainer)
        b.rootTilingContainer.apply {
            TestWindow.new(id: 5, parent: $0)
        }

        await parseCommand("swap-workspaces a b").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(a.rootTilingContainer.layoutDescription, .h_tiles([.window(5)]))
        assertEquals(b.rootTilingContainer.layoutDescription, .h_tiles([.window(1), .v_tiles([.window(2), .window(3)])]))
        assertEquals(a.floatingWindows.map(\.windowId), [])
        assertEquals(b.floatingWindows.map(\.windowId), [4])
        // The user stays on workspace "a" and sees what used to be on "b"
        assertEquals(globalFocus.workspace.name, "a")
        assertEquals(globalFocus.windowOrNil?.windowId, 5)
    }

    @Test func testSwapKeepsTheMostRecentWindow() async {
        let a = Workspace.get(byName: "a")
        let b = Workspace.get(byName: "b")
        a.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }
        var w3: TestWindow? = nil
        b.rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
            w3 = TestWindow.new(id: 3, parent: $0)
        }
        TestWindow.new(id: 4, parent: b.floatingWindowsContainer)
        w3?.markAsMostRecentChild() // The tiling window was used last, the floating one was merely bound last

        await parseCommand("swap-workspaces a b").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(globalFocus.workspace.name, "a")
        assertEquals(globalFocus.windowOrNil?.windowId, 3)
    }

    @Test func testSwapWithEmptyWorkspace() async {
        let a = Workspace.get(byName: "a")
        let b = Workspace.get(byName: "b")
        a.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }

        await parseCommand("swap-workspaces a b").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(a.rootTilingContainer.layoutDescription, .h_tiles([]))
        assertEquals(b.rootTilingContainer.layoutDescription, .h_tiles([.window(1)]))
        assertEquals(globalFocus.workspace.name, "a")
    }

    @Test func testSwapWithItselfFails() async {
        let result = await parseCommand("swap-workspaces a a").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Can't swap workspace 'a' with itself"])
    }
}
