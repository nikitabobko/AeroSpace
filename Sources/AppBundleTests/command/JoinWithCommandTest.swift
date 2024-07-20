import XCTest
import Common
@testable import AppBundle

final class JoinWithCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testMoveIn() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 0, parent: $0)
            assertEquals(TestWindow(id: 1, parent: $0).focusWindow(), true)
            TestWindow(id: 2, parent: $0)
        }

        JoinWithCommand(args: JoinWithCmdArgs(rawArgs: [], direction: .right)).run(.focused)
        assertEquals(root.layoutDescription, .h_tiles([
            .window(0),
            .v_tiles([
                .window(1),
                .window(2)
            ])
        ]))
    }
}
