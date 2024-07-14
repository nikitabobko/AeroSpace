@testable import AppBundle
import Common
import XCTest

final class MoveNodeToWorkspaceCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseCommandSucc("move-node-to-workspace next", MoveNodeToWorkspaceCmdArgs(target: .relative(true)))
    }

    func testSimple() {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b")).run(.defaultEnv, .emptyStdin)
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        assertEquals((Workspace.get(byName: "b").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testEmptyWorkspaceSubject() {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        _ = MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b")).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "a")
    }

    func testAnotherWindowSubject() {
        let workspaceA = Workspace.get(byName: "a")
        var window1: Window!
        workspaceA.rootTilingContainer.apply {
            window1 = TestWindow.new(id: 1, parent: $0)
            _ = TestWindow.new(id: 2, parent: $0).focusWindow()
        }

        _ = MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b")).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil, window1)
    }

    func testPreserveFloatingLayout() {
        let workspaceA = Workspace.get(byName: "a").apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b")).run(.defaultEnv, .emptyStdin)
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        assertEquals(Workspace.get(byName: "b").children.filterIsInstance(of: Window.self).singleOrNil()?.windowId, 1)
    }
}
