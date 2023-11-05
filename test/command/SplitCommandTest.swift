import XCTest
@testable import AeroSpace_Debug

final class SplitCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testSplit() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0).focus()
            TestWindow(id: 2, parent: $0)
        }

        await SplitCommand(splitArg: .vertical).runWithoutLayout()
        XCTAssertEqual(root.layoutDescription, .h_list([
            .v_list([
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

        await SplitCommand(splitArg: .opposite).runWithoutLayout()
        XCTAssertEqual(root.layoutDescription, .h_list([
            .v_list([
                .window(1)
            ]),
            .window(2),
        ]))
    }

    func testChangeOrientation() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVList(parent: $0, adaptiveWeight: 1).apply {
                TestWindow(id: 1, parent: $0).focus()
            }
            TestWindow(id: 2, parent: $0)
        }

        await SplitCommand(splitArg: .horizontal).runWithoutLayout()
        XCTAssertEqual(root.layoutDescription, .h_list([
            .h_list([
                .window(1)
            ]),
            .window(2),
        ]))
    }

    func testToggleOrientation() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVList(parent: $0, adaptiveWeight: 1).apply {
                TestWindow(id: 1, parent: $0).focus()
            }
            TestWindow(id: 2, parent: $0)
        }

        await SplitCommand(splitArg: .opposite).runWithoutLayout()
        XCTAssertEqual(root.layoutDescription, .h_list([
            .h_list([
                .window(1)
            ]),
            .window(2),
        ]))
    }
}
