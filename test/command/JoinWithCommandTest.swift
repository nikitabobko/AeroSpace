import XCTest
@testable import AeroSpace_Debug

final class JoinWithCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testMoveIn() {
        var start: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 0, parent: $0)
            start = TestWindow(id: 1, parent: $0)
            TestWindow(id: 2, parent: $0)
        }
        start.focus()

        JoinWithCommand(args: JoinWithCmdArgs(direction: .right)).runOnFocusedSubject()
        XCTAssertEqual(root.layoutDescription, .h_tiles([
            .window(0),
            .v_tiles([
                .window(1),
                .window(2)
            ])
        ]))
    }
}
