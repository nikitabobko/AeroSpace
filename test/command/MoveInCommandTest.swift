import XCTest
@testable import AeroSpace_Debug

final class MoveInCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testMoveIn() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 0, parent: $0)
            TestWindow(id: 1, parent: $0).focus()
            TestWindow(id: 2, parent: $0)
        }

        await MoveInCommand(direction: .right).runWithoutLayout()
        XCTAssertEqual(root.layoutDescription, .h_list([
            .window(0),
            .v_list([
                .window(1),
                .window(2)
            ])
        ]))
    }
}
