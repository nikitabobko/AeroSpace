@testable import AppBundle
import Common
import XCTest

final class BalanceSizesCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testBalanceSizesCommand() {
        let workspace = Workspace.get(byName: name).apply { wsp in
            wsp.rootTilingContainer.apply {
                TestWindow(id: 1, parent: $0).setWeight(wsp.rootTilingContainer.orientation, 1)
                TestWindow(id: 2, parent: $0).setWeight(wsp.rootTilingContainer.orientation, 2)
                TestWindow(id: 3, parent: $0).setWeight(wsp.rootTilingContainer.orientation, 3)
            }
        }

        BalanceSizesCommand(args: BalanceSizesCmdArgs(rawArgs: []))
            .run(CommandMutableState(.emptyWorkspace(name)))

        for window in workspace.rootTilingContainer.children {
            assertEquals(window.getWeight(workspace.rootTilingContainer.orientation), 1)
        }
    }
}
