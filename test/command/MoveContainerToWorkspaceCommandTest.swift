import XCTest
@testable import AeroSpace_Debug

final class MoveContainerToWorkspaceCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }
    override func tearDownWithError() throws { tearDownWorkspacesForTests() }

    func testSimple() async {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0).focus()
        }

        await MoveContainerToWorkspaceCommand(targetWorkspaceName: "b").runWithoutRefresh()
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        XCTAssertTrue(focusedWindow == nil)
        XCTAssertEqual((Workspace.get(byName: "b").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testPreserveFloatingLayout() async {
        let workspaceA = Workspace.get(byName: "a").apply {
            TestWindow(id: 1, parent: $0).focus()
        }

        await MoveContainerToWorkspaceCommand(targetWorkspaceName: "b").runWithoutRefresh()
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        XCTAssertTrue(focusedWindow == nil)
        XCTAssertEqual(Workspace.get(byName: "b").children.filterIsInstance(of: Window.self).singleOrNil()?.windowId, 1)
    }
}
