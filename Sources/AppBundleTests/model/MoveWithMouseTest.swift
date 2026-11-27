@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct MoveWithMouseTest {
    init() { setUpWorkspacesForTests() }

    // Some apps report AXMoved on every position write. Refreshing on AXMoved of a window hidden in the corner makes
    // hideInCorner re-trigger the refresh session forever
    @Test func testMovedHiddenInCornerWindowDoesNotScheduleRefresh() async throws {
        let window = TestWindow.new(id: 1, parent: Workspace.get(byName: name).rootTilingContainer)
        window.isHiddenInCornerForTest = true
        let before = activeRefreshTask

        try await onWindowMoved(window, "AXMoved")

        assertTrue(activeRefreshTask == before)
    }
}
