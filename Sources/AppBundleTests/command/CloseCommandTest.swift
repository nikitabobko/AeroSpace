@testable import AppBundle
import Common
import XCTest

@MainActor
final class CloseCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSimple() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(focus.workspace.rootTilingContainer.children.count, 2)

        try await CloseCommand(args: CloseCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)

        assertEquals(focus.windowOrNil?.windowId, 2)
        assertEquals(focus.workspace.rootTilingContainer.children.count, 1)
    }

    func testCloseViaWindowIdFlag() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(focus.workspace.rootTilingContainer.children.count, 2)

        try await CloseCommand(args: CloseCmdArgs(rawArgs: []).copy(\.windowId, 2)).run(.defaultEnv, .emptyStdin)

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(focus.workspace.rootTilingContainer.children.count, 1)
    }
}
