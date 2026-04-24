@testable import AppBundle
import Common
import XCTest

@MainActor
final class RaiseRouterTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    // §D7: raises targeting a window on a non-focused workspace must be
    // dropped. This matches i3 behavior and prevents surprise workspace
    // flips when the cursor enters a screen region owned by a non-active
    // workspace (e.g. on another monitor).
    func testDropsRaiseToNonFocusedWorkspace() {
        let workspaceA = Workspace.get(byName: "a").apply {
            _ = TestWindow.new(id: 1, parent: $0.rootTilingContainer).focusWindow()
        }
        Workspace.get(byName: "b").rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
        }
        assertEquals(focus.workspace, workspaceA)
        assertEquals(focus.windowOrNil?.windowId, 1)

        RaiseRouter.route(windowId: CGWindowID(2))

        assertEquals(focus.workspace, workspaceA)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testRaisesWindowOnFocusedWorkspace() {
        let workspaceA = Workspace.get(byName: "a").apply {
            _ = TestWindow.new(id: 1, parent: $0.rootTilingContainer).focusWindow()
            TestWindow.new(id: 2, parent: $0.rootTilingContainer)
        }
        assertEquals(focus.workspace, workspaceA)
        assertEquals(focus.windowOrNil?.windowId, 1)

        RaiseRouter.route(windowId: CGWindowID(2))

        assertEquals(focus.workspace, workspaceA)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testIgnoresUnknownWindowId() {
        let workspaceA = Workspace.get(byName: "a").apply {
            _ = TestWindow.new(id: 1, parent: $0.rootTilingContainer).focusWindow()
        }

        RaiseRouter.route(windowId: CGWindowID(999))

        assertEquals(focus.workspace, workspaceA)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }
}
