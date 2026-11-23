@testable import AppBundle
import Common
import Foundation
import Testing

@MainActor
@Suite(.serializedGlobally)
struct MonitorTest {
    init() { setUpWorkspacesForTests() }

    @Test func testLayoutFollowsDisplayReplacementAndVisibleFrameChanges() async throws {
        let workspace = globalFocus.workspace
        let root = workspace.rootTilingContainer
        let window = TestWindow.new(id: 1, parent: root)
        let monitor = mainMonitorInfo.toMonitorOrRearrangeMonitors()
        defer { _ = mainMonitorInfo.toMonitorOrRearrangeMonitors() }

        let internalDisplay = TestMonitorInfo(
            name: "Built-in display",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1512, height: 982),
            visibleRect: Rect(topLeftX: 0, topLeftY: 38, width: 1512, height: 944),
        )
        let externalDisplay = TestMonitorInfo(
            name: "External display",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 2560, height: 1440),
            visibleRect: Rect(topLeftX: 0, topLeftY: 25, width: 2560, height: 1415),
        )
        let externalDisplayWithDock = TestMonitorInfo(
            name: externalDisplay.name,
            rect: externalDisplay.rect,
            visibleRect: Rect(topLeftX: 80, topLeftY: 25, width: 2480, height: 1415),
        )

        for layout: Layout in [.tiles, .accordion, .tabs, .scrolling] {
            root.layout = layout
            for info in [internalDisplay, externalDisplay, externalDisplayWithDock, internalDisplay] {
                #expect(info.visibleWorkspace === workspace)
                #expect(info.toMonitorOrRearrangeMonitors() === monitor)
                #expect(workspace.workspaceMonitorInfo.name == info.name)
                #expect(workspace.workspaceMonitorInfo.rect.size == info.rect.size)

                _ = try await workspace.layoutWorkspace()

                let viewport = info.visibleRectPaddedByOuterGaps
                let headerHeight = layout == .tabs ? TabHeaderMetrics.height : 0
                let actual = try #require(await window.getAxRect(.nonCancellable))
                #expect(actual.topLeftCorner == viewport.topLeftCorner + Point(x: 0, y: headerHeight))
                #expect(actual.width == viewport.width)
                #expect(actual.height == viewport.height - 1 - headerHeight)
            }
        }
    }
}

private struct TestMonitorInfo: MonitorInfo {
    let name: String
    let rect: Rect
    let visibleRect: Rect
    var width: CGFloat { rect.width }
    var height: CGFloat { rect.height }
    let monitorAppKitNsScreenScreensId = 1
    let isMain = true
}
