@testable import AppBundle
import AppKit
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct MonitorGeometryTest {
    init() { setUpWorkspacesForTests() }

    @Test func testGeometryRefreshesWhenDisplaySizeChangesAtSameOrigin() {
        let workspace = globalFocus.workspace
        let monitor = workspace.nodeMonitorInfo.orDie().toMonitorOrRearrangeMonitors()
        let resizedMonitor = ResizedMonitorInfo(
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1728, height: 1117),
        )
        defer { gcMonitors() }

        gcMonitors([resizedMonitor])

        assertTrue(workspace.nodeMonitorInfo.orDie().toMonitorOrRearrangeMonitors() === monitor)
        assertEquals(workspace.workspaceMonitorInfo.rect.width, 1728)
        assertEquals(workspace.rootTilingContainer.hWeight, 1728)
    }
}

private struct ResizedMonitorInfo: MonitorInfo {
    let monitorAppKitNsScreenScreensId = 1
    let name = "Test Monitor"
    let rect: Rect
    var visibleRect: Rect { rect }
    var width: CGFloat { rect.width }
    var height: CGFloat { rect.height }
    let isMain = true
}
