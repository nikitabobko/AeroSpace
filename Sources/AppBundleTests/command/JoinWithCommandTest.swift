@testable import AppBundle
import Common
import XCTest

@MainActor
final class JoinWithCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testMoveIn() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 0, parent: $0)
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        await parseCommand("join-with right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([
            .window(0),
            .v_tiles([
                .window(1),
                .window(2),
            ]),
        ]))
    }

    func testJoinWithContainer() async {
        var window3: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                window3 = TestWindow.new(id: 3, parent: $0)
                TestWindow.new(id: 4, parent: $0)
            }
        }
        window3.markAsMostRecentChild()

        await parseCommand("join-with right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([
            .window(1),
            .v_tiles([
                .window(3),
                .window(2),
                .window(4),
            ]),
        ]))
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testJoinWithContainer_left() async {
        var window1: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                window1 = TestWindow.new(id: 1, parent: $0)
                TestWindow.new(id: 2, parent: $0)
            }
            assertEquals(TestWindow.new(id: 3, parent: $0).focusWindow(), true)
        }
        window1.markAsMostRecentChild()

        await parseCommand("join-with left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([
            .v_tiles([
                .window(1),
                .window(3),
                .window(2),
            ]),
        ]))
    }

    func testJoinWithContainer_fromNestedWindow() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 1, parent: $0)
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            }
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 3, parent: $0)
                TestWindow.new(id: 4, parent: $0)
            }
        }

        await parseCommand("join-with right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([
            .v_tiles([
                .window(1),
            ]),
            .v_tiles([
                .window(3),
                .window(4),
                .window(2),
            ]),
        ]))
    }

    func testJoinWithContainer_mru() async {
        var window3: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 2, parent: $0)
                    window3 = TestWindow.new(id: 3, parent: $0)
                }
                TestWindow.new(id: 4, parent: $0)
            }
        }
        window3.markAsMostRecentChild()

        await parseCommand("join-with right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([
            .v_tiles([
                .h_tiles([
                    .window(1),
                    .window(2),
                    .window(3),
                ]),
                .window(4),
            ]),
        ]))
    }
}
