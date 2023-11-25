import XCTest
@testable import AeroSpace_Debug

final class MoveNodeToWorkspaceCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testSimple() {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0).focus()
        }

        MoveNodeToWorkspaceCommand(targetWorkspaceName: "b").testRun()
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        XCTAssertEqual((Workspace.get(byName: "b").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testPreserveFloatingLayout() {
        let workspaceA = Workspace.get(byName: "a").apply {
            TestWindow(id: 1, parent: $0).focus()
        }

        MoveNodeToWorkspaceCommand(targetWorkspaceName: "b").testRun()
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        XCTAssertEqual(Workspace.get(byName: "b").children.filterIsInstance(of: Window.self).singleOrNil()?.windowId, 1)
    }
}
