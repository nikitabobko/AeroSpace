import XCTest
@testable import AeroSpace_Debug

final class MoveContainerToWorkspaceCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testSimple() async {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0).focus()
        }

        XCTAssertTrue(focusedWorkspaceSourceOfTruth == .macOs)
        await MoveContainerToWorkspaceCommand(targetWorkspaceName: "b").runWithoutLayout()
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        XCTAssertTrue(focusedWorkspaceSourceOfTruth == .ownModel)
        XCTAssertEqual((Workspace.get(byName: "b").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testPreserveFloatingLayout() async {
        let workspaceA = Workspace.get(byName: "a").apply {
            TestWindow(id: 1, parent: $0).focus()
        }

        XCTAssertTrue(focusedWorkspaceSourceOfTruth == .macOs)
        await MoveContainerToWorkspaceCommand(targetWorkspaceName: "b").runWithoutLayout()
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        XCTAssertTrue(focusedWorkspaceSourceOfTruth == .ownModel)
        XCTAssertEqual(Workspace.get(byName: "b").children.filterIsInstance(of: Window.self).singleOrNil()?.windowId, 1)
    }
}
