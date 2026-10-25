@testable import AppBundle
import Common
import XCTest

// https://github.com/nikitabobko/AeroSpace/issues/1287
@MainActor
final class DoesVisibleWorkspaceCoverMonitorTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testEmptyWorkspace_doesNotCoverMonitor() {
        assertEquals(mainMonitorInfo.doesVisibleWorkspaceCoverMonitor, false)
    }

    func testSingleTilingWindow_coversMonitor() {
        TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        assertEquals(mainMonitorInfo.doesVisibleWorkspaceCoverMonitor, true)
    }

    func testTwoTilingWindows_dontCoverMonitor() {
        focus.workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
        }
        assertEquals(mainMonitorInfo.doesVisibleWorkspaceCoverMonitor, false)
    }

    // Floating windows don't affect the coverage: the single tiling window is still laid out
    // over the whole monitor and covers windows of invisible workspaces anyway
    func testSingleTilingWindowWithFloatingWindow_coversMonitor() {
        TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        TestWindow.new(id: 2, parent: focus.workspace.floatingWindowsContainer)
        assertEquals(mainMonitorInfo.doesVisibleWorkspaceCoverMonitor, true)
    }
}
