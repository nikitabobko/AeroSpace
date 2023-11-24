import XCTest
@testable import AeroSpace_Debug

final class MoveNodeToWorkspaceCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testSimple() async {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0).nativeFocus()
        }

        XCTAssertTrue(focusSourceOfTruth == .macOs)
        MoveNodeToWorkspaceCommand(targetWorkspaceName: "b").testRun()
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        XCTAssertTrue(focusSourceOfTruth == .ownModel)
        XCTAssertEqual((Workspace.get(byName: "b").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testPreserveFloatingLayout() async {
        let workspaceA = Workspace.get(byName: "a").apply {
            TestWindow(id: 1, parent: $0).nativeFocus()
        }

        XCTAssertTrue(focusSourceOfTruth == .macOs)
        MoveNodeToWorkspaceCommand(targetWorkspaceName: "b").testRun()
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        XCTAssertTrue(focusSourceOfTruth == .ownModel)
        XCTAssertEqual(Workspace.get(byName: "b").children.filterIsInstance(of: Window.self).singleOrNil()?.windowId, 1)
    }
}
