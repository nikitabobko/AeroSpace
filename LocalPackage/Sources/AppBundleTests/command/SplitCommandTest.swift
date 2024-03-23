import XCTest
import Common
@testable import AeroSpace_Debug

final class SplitCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testSplit() {
        var start: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            start = TestWindow(id: 1, parent: $0)
            TestWindow(id: 2, parent: $0)
        }
        start.focus()

        SplitCommand(args: SplitCmdArgs(.vertical)).run(.focused)
        XCTAssertEqual(root.layoutDescription, .h_tiles([
            .v_tiles([
                .window(1)
            ]),
            .window(2),
        ]))
    }

    func testSplitOppositeOrientation() {
        var start: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            start = TestWindow(id: 1, parent: $0)
            TestWindow(id: 2, parent: $0)
        }
        start.focus()

        SplitCommand(args: SplitCmdArgs(.opposite)).run(.focused)
        XCTAssertEqual(root.layoutDescription, .h_tiles([
            .v_tiles([
                .window(1)
            ]),
            .window(2),
        ]))
    }

    func testChangeOrientation() {
        var start: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                start = TestWindow(id: 1, parent: $0)
            }
            TestWindow(id: 2, parent: $0)
        }
        start.focus()

        SplitCommand(args: SplitCmdArgs(.horizontal)).run(.focused)
        XCTAssertEqual(root.layoutDescription, .h_tiles([
            .h_tiles([
                .window(1)
            ]),
            .window(2),
        ]))
    }

    func testToggleOrientation() {
        var start: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                start = TestWindow(id: 1, parent: $0)
            }
            TestWindow(id: 2, parent: $0)
        }
        start.focus()

        SplitCommand(args: SplitCmdArgs(.opposite)).run(.focused)
        XCTAssertEqual(root.layoutDescription, .h_tiles([
            .h_tiles([
                .window(1)
            ]),
            .window(2),
        ]))
    }
}
