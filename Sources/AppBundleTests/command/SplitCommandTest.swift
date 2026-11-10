@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct SplitCommandTest {
    init() { setUpWorkspacesForTests() }

    @Test func testSplit() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        await parseCommand("split vertical").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([
            .v_tiles([
                .window(1),
            ]),
            .window(2),
        ]))
    }

    @Test func testSplit_onlyTombstoneSiblings_changesOrientationInstead() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0).lifeStatus = .dead
        }

        await parseCommand("split vertical").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .v_tiles([.window(1), .window(2)]))
    }

    @Test func testSplitOppositeOrientation() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        await parseCommand("split opposite").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([
            .v_tiles([
                .window(1),
            ]),
            .window(2),
        ]))
    }

    @Test func testChangeOrientation() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            }
            TestWindow.new(id: 2, parent: $0)
        }

        await parseCommand("split horizontal").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([
            .h_tiles([
                .window(1),
            ]),
            .window(2),
        ]))
    }

    @Test func testToggleOrientation() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            }
            TestWindow.new(id: 2, parent: $0)
        }

        await parseCommand("split opposite").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([
            .h_tiles([
                .window(1),
            ]),
            .window(2),
        ]))
    }

    @Test func testSplitVerticalFailsInScrollingLayout() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }
        root.layout = .scrolling

        let result = await parseCommand("split vertical").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["The scrolling layout is always horizontal"])
        assertEquals(root.layoutDescription, .scrolling([.window(1)]))
        assertEquals(root.orientation, .h)
    }
}
