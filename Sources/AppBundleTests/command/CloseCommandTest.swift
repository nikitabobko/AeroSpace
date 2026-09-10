@testable import AppBundle
import Common
import XCTest

@MainActor
final class CloseCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSimple() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(globalFocus.windowOrNil?.windowId, 1)
        assertEquals(globalFocus.workspace.rootTilingContainer.children.count, 2)

        await parseCommand("close").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(globalFocus.windowOrNil?.windowId, 2)
        assertEquals(globalFocus.workspace.rootTilingContainer.children.count, 1)
    }

    func testCloseViaWindowIdFlag() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(globalFocus.windowOrNil?.windowId, 1)
        assertEquals(globalFocus.workspace.rootTilingContainer.children.count, 2)

        await parseCommand("close --window-id 2").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(globalFocus.windowOrNil?.windowId, 1)
        assertEquals(globalFocus.workspace.rootTilingContainer.children.count, 1)
    }
}
