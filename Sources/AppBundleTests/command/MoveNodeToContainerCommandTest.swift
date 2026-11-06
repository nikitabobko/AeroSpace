@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct MoveNodeToContainerCommandTest {
    init() { setUpWorkspacesForTests() }

    @Test func testParse() {
        assertEquals(parseCommand("move-node-to-container").errorOrNil, "ERROR: Argument '<workspace-name>' is mandatory\nERROR: Argument '<container-path>' is mandatory\nERROR: Argument '<index>' is mandatory")
        assertEquals(parseCommand("move-node-to-container 1 /").errorOrNil, "ERROR: Argument '<index>' is mandatory")
        assertEquals(parseCommand("move-node-to-container 1 0 0").errorOrNil, "ERROR: Container path must start with '/'. Expected format: '/' or '/<index>/<index>/...'. For example: '/0/1'")
        assertEquals(parseCommand("move-node-to-container 1 /a 0").errorOrNil, "ERROR: Can't parse container path '/a'. Expected format: '/' or '/<index>/<index>/...'. For example: '/0/1'")
        assertEquals(parseCommand("move-node-to-container 1 / x").errorOrNil, "ERROR: <index> must be a non-negative integer. Got: 'x'")
        assertNil(parseCommand("move-node-to-container 1 / 0").errorOrNil)
        assertNil(parseCommand("move-node-to-container --window-id 1 --focus-follows-window 1 /0/1 2").errorOrNil)
        assertNil(parseCommand("move-node-to-container -- 1 /0 0").errorOrNil)
    }

    @Test func testMoveIntoNestedContainer() async {
        let root = Workspace.get(byName: "a").rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 2, parent: $0)
                TestWindow.new(id: 3, parent: $0)
            }
            assertEquals(TestWindow.new(id: 4, parent: $0).focusWindow(), true)
        }

        await parseCommand("move-node-to-container a /1 1").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([
            .window(1),
            .v_tiles([
                .window(2),
                .window(4),
                .window(3),
            ]),
        ]))
    }

    @Test func testMoveWithinTheSameContainer() async {
        let root = Workspace.get(byName: "a").rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }

        // <index> refers to the children list before the move
        await parseCommand("move-node-to-container a / 3").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(2), .window(3), .window(1)]))

        await parseCommand("move-node-to-container --window-id 3 a / 0").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(3), .window(2), .window(1)]))

        await parseCommand("move-node-to-container --window-id 3 a / 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(2), .window(3), .window(1)]))
    }

    @Test func testMoveToAnotherWorkspace() async {
        let a = Workspace.get(byName: "a")
        let b = Workspace.get(byName: "b")
        assertEquals(TestWindow.new(id: 1, parent: a.rootTilingContainer).focusWindow(), true)
        TestWindow.new(id: 2, parent: b.rootTilingContainer)

        await parseCommand("move-node-to-container --focus-follows-window b / 0").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(a.layoutDescription, .workspace([.h_tiles([])]))
        assertEquals(b.rootTilingContainer.layoutDescription, .h_tiles([.window(1), .window(2)]))
        assertEquals(globalFocus.windowOrNil?.windowId, 1)
        assertEquals(globalFocus.workspace, b)
    }

    @Test func testMoveFloatingWindowMakesItTiling() async {
        let workspace = Workspace.get(byName: "a")
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(TestWindow.new(id: 2, parent: workspace.floatingWindowsContainer).focusWindow(), true)

        await parseCommand("move-node-to-container a / 0").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([.window(2), .window(1)]))
        assertEquals(workspace.floatingWindows.count, 0)
    }

    @Test func testInvalidPath() async {
        let root = Workspace.get(byName: "a").rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        let result = await parseCommand("move-node-to-container a /1 0").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Container '/1' doesn't exist in workspace 'a'"])
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))
    }

    @Test func testIndexOutOfBounds() async {
        let root = Workspace.get(byName: "a").rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        let result = await parseCommand("move-node-to-container a / 3").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Index 3 is out of bounds. Container '/' in workspace 'a' has 2 children"])
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))
    }
}
