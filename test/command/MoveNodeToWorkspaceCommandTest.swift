import XCTest
import Common
@testable import AeroSpace_Debug

final class MoveNodeToWorkspaceCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParse() {
        XCTAssertEqual(
            parseCommand("move-node-to-workspace next").cmdOrNil?.describe,
            .moveNodeToWorkspace(args: MoveNodeToWorkspaceCmdArgs(target: .next(wrapAround: false)))
        )
    }

    func testSimple() {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0).focus()
        }

        MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(target: .workspaceName(name: "b", autoBackAndForth: false))).runOnFocusedSubject()
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        XCTAssertEqual((Workspace.get(byName: "b").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testEmptyWorkspaceSubject() {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0).focus()
        }

        var subject = CommandSubject.focused
        var devNull: [String] = []

        MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(target: .workspaceName(name: "b", autoBackAndForth: false)))
            .run(&subject, &devNull)

        XCTAssertEqual(subject, .emptyWorkspace("a"))
    }

    func testAnotherWindowSubject() {
        let workspaceA = Workspace.get(byName: "a")
        var window1: Window!
        workspaceA.rootTilingContainer.apply {
            window1 = TestWindow(id: 1, parent: $0)
            TestWindow(id: 2, parent: $0).focus()
        }

        var subject = CommandSubject.focused
        var devNull: [String] = []

        MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(target: .workspaceName(name: "b", autoBackAndForth: false)))
            .run(&subject, &devNull)

        XCTAssertEqual(subject, .window(window1))
    }

    func testPreserveFloatingLayout() {
        let workspaceA = Workspace.get(byName: "a").apply {
            TestWindow(id: 1, parent: $0).focus()
        }

        MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(target: .workspaceName(name: "b", autoBackAndForth: false))).runOnFocusedSubject()
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        XCTAssertEqual(Workspace.get(byName: "b").children.filterIsInstance(of: Window.self).singleOrNil()?.windowId, 1)
    }
}
