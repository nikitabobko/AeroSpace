import XCTest
@testable import AeroSpace_Debug

final class SplitCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testSplit() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0).focus()
            TestWindow(id: 2, parent: $0)
        }

        await SplitCommand(splitArg: .vertical).testRun()
        XCTAssertEqual(root.layoutDescription, .h_tiles([
            .v_tiles([
                .window(1)
            ]),
            .window(2),
        ]))
    }

    func testSplitOppositeOrientation() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0).focus()
            TestWindow(id: 2, parent: $0)
        }

        await SplitCommand(splitArg: .opposite).testRun()
        XCTAssertEqual(root.layoutDescription, .h_tiles([
            .v_tiles([
                .window(1)
            ]),
            .window(2),
        ]))
    }

    func testChangeOrientation() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow(id: 1, parent: $0).focus()
            }
            TestWindow(id: 2, parent: $0)
        }

        await SplitCommand(splitArg: .horizontal).testRun()
        XCTAssertEqual(root.layoutDescription, .h_tiles([
            .h_tiles([
                .window(1)
            ]),
            .window(2),
        ]))
    }

    func testToggleOrientation() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow(id: 1, parent: $0).focus()
            }
            TestWindow(id: 2, parent: $0)
        }

        await SplitCommand(splitArg: .opposite).testRun()
        XCTAssertEqual(root.layoutDescription, .h_tiles([
            .h_tiles([
                .window(1)
            ]),
            .window(2),
        ]))
    }
}
