import XCTest
import Common
@testable import AppBundle

final class MoveNodeToWorkspaceCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseCommandSucc("move-node-to-workspace next", MoveNodeToWorkspaceCmdArgs(rawArgs: [], .relative(WTarget.Relative(isNext: true, wrapAround: false))))
    }

    func testSimple() {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            _ = TestWindow(id: 1, parent: $0).focusWindow()
        }

        MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(rawArgs: [], .direct(WTarget.Direct("b")))).run(.focused)
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        assertEquals((Workspace.get(byName: "b").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testEmptyWorkspaceSubject() {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            _ = TestWindow(id: 1, parent: $0).focusWindow()
        }

        let state: CommandMutableState = .focused

        _ = MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(rawArgs: [], .direct(WTarget.Direct("b"))))
            .run(state)

        assertEquals(state.subject, .emptyWorkspace("a"))
    }

    func testAnotherWindowSubject() {
        let workspaceA = Workspace.get(byName: "a")
        var window1: Window!
        workspaceA.rootTilingContainer.apply {
            window1 = TestWindow(id: 1, parent: $0)
            _ = TestWindow(id: 2, parent: $0).focusWindow()
        }

        let state: CommandMutableState = .focused

        _ = MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(rawArgs: [], .direct(WTarget.Direct("b"))))
            .run(state)

        assertEquals(state.subject, .window(window1))
    }

    func testPreserveFloatingLayout() {
        let workspaceA = Workspace.get(byName: "a").apply {
            _ = TestWindow(id: 1, parent: $0).focusWindow()
        }

        MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(rawArgs: [], .direct(WTarget.Direct("b")))).run(.focused)
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        assertEquals(Workspace.get(byName: "b").children.filterIsInstance(of: Window.self).singleOrNil()?.windowId, 1)
    }
}
