@testable import AppBundle
import Common
import XCTest

final class SplitCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testSplit() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        SplitCommand(args: SplitCmdArgs(rawArgs: [], .vertical)).run(.focused)
        assertEquals(root.layoutDescription, .h_tiles([
            .v_tiles([
                .window(1),
            ]),
            .window(2),
        ]))
    }

    func testSplitOppositeOrientation() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        SplitCommand(args: SplitCmdArgs(rawArgs: [], .opposite)).run(.focused)
        assertEquals(root.layoutDescription, .h_tiles([
            .v_tiles([
                .window(1),
            ]),
            .window(2),
        ]))
    }

    func testChangeOrientation() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            }
            TestWindow.new(id: 2, parent: $0)
        }

        SplitCommand(args: SplitCmdArgs(rawArgs: [], .horizontal)).run(.focused)
        assertEquals(root.layoutDescription, .h_tiles([
            .h_tiles([
                .window(1),
            ]),
            .window(2),
        ]))
    }

    func testToggleOrientation() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            }
            TestWindow.new(id: 2, parent: $0)
        }

        SplitCommand(args: SplitCmdArgs(rawArgs: [], .opposite)).run(.focused)
        assertEquals(root.layoutDescription, .h_tiles([
            .h_tiles([
                .window(1),
            ]),
            .window(2),
        ]))
    }
}
