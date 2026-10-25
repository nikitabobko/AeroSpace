@testable import AppBundle
import Common
import XCTest

@MainActor
final class WorkspaceTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    // Asking a stale MonitorInfo (from an outdated display configuration snapshot) for its
    // activeWorkspace must degrade to the closest currently attached monitor instead of
    // crashing with unbounded recursion
    // https://github.com/nikitabobko/AeroSpace/issues/506
    func testActiveWorkspace_staleMonitor_degradesToClosestSeatedMonitor() {
        let staleMonitor = newTestMonitorInfo(
            rect: Rect(topLeftX: 2000, topLeftY: 0, width: 1920, height: 1080),
            isMain: false,
        )
        assertEquals(staleMonitor.activeWorkspace, focus.workspace)
        // The real monitor must be unaffected
        assertEquals(mainMonitorInfo.activeWorkspace, focus.workspace)
    }
}
