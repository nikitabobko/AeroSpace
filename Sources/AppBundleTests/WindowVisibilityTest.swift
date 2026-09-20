@testable import AppBundle
import Common
import XCTest

@MainActor
final class WindowVisibilityTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testDisablingRestoresHiddenPagesAndTabsAndPreservesTheirLayouts() async throws {
        let wasEnabled = TrayMenuModel.shared.isEnabled
        defer { TrayMenuModel.shared.isEnabled = wasEnabled }
        TrayMenuModel.shared.isEnabled = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.layout = .scrolling
        let hiddenPage = TestWindow.new(id: 1, parent: root)
        let tabs = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tabs, index: INDEX_BIND_LAST)
        let inactiveTab = TestWindow.new(id: 2, parent: tabs)
        let activeTab = TestWindow.new(id: 3, parent: tabs)
        TestWindow.new(id: 4, parent: root)
        assertEquals(activeTab.focusWindow(), true)
        root.scrollingIndex = 1
        _ = try await workspace.layoutWorkspace()
        assertEquals(hiddenPage.isHiddenInCorner, true)
        assertEquals(inactiveTab.isHiddenInCorner, true)

        TrayMenuModel.shared.isEnabled = false
        let disabledHeaders = try await workspace.layoutWorkspace()

        assertEquals(disabledHeaders.count, 0)
        for window in workspace.allLeafWindowsRecursive {
            assertEquals(window.isHiddenInCorner, false)
            let rect = try await window.getAxRect(.nonCancellable).orDie()
            assertEquals(workspace.workspaceMonitor.visibleRect.contains(rect.center), true)
        }
        assertEquals(root.layout, .scrolling)
        assertEquals(tabs.layout, .tabs)
        assertEquals(root.scrollingIndex, 1)
        assertEquals(tabs.mostRecentChild, activeTab)

        TrayMenuModel.shared.isEnabled = true
        let restoredHeaders = try await workspace.layoutWorkspace()
        assertEquals(restoredHeaders.count, 1)
        assertEquals(hiddenPage.isHiddenInCorner, true)
        assertEquals(inactiveTab.isHiddenInCorner, true)
        assertEquals(activeTab.isHiddenInCorner, false)
    }

    func testScrollingWindowsStayHiddenAcrossWorkspaceSwitches() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.layout = .scrolling
        let tabs = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tabs, index: INDEX_BIND_LAST)
        let inactiveTab = TestWindow.new(id: 1, parent: tabs)
        let activeTab = TestWindow.new(id: 2, parent: tabs)
        let otherPage = TestWindow.new(id: 3, parent: root)
        let hiddenPage = TestWindow.new(id: 4, parent: root)
        assertEquals(activeTab.focusWindow(), true)

        _ = try await workspace.layoutWorkspace()
        let hiddenPageSize = try await hiddenPage.getAxSize(.nonCancellable)
        let corner = workspace.workspaceMonitor.optimalHideCorner(monitors: monitorInfos)

        // The workspace hiding pass must preserve the state of already hidden tabs/pages.
        for window in workspace.allLeafWindowsRecursive {
            try await window.hideInCorner(corner)
        }
        _ = try await workspace.layoutWorkspace()

        assertEquals(inactiveTab.isHiddenInCorner, true)
        assertEquals(hiddenPage.isHiddenInCorner, true)
        assertEquals(activeTab.isHiddenInCorner, false)
        assertEquals(otherPage.isHiddenInCorner, false)
        let restoredHiddenSize = try await hiddenPage.getAxSize(.nonCancellable)
        assertEquals(restoredHiddenSize, hiddenPageSize)

        root.scrollingIndex = 1
        _ = try await workspace.layoutWorkspace()
        assertEquals(inactiveTab.isHiddenInCorner, true)
        assertEquals(activeTab.isHiddenInCorner, true)
        assertEquals(hiddenPage.isHiddenInCorner, false)

        root.scrollingIndex = 0
        _ = try await workspace.layoutWorkspace()
        assertEquals(inactiveTab.isHiddenInCorner, true)
        assertEquals(activeTab.isHiddenInCorner, false)
        assertEquals(hiddenPage.isHiddenInCorner, true)
    }

    func testHiddenTabRestoresWhenMadeFloating() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let original = Rect(topLeftX: 100, topLeftY: 100, width: 600, height: 400)
        let window = TestWindow.new(id: 1, parent: root, rect: original)
        TestWindow.new(id: 2, parent: root)
        root.layout = .tabs

        _ = try await workspace.layoutWorkspace()
        assertEquals(window.isHiddenInCorner, true)

        window.bindAsFloatingWindow(to: workspace)
        _ = try await workspace.layoutWorkspace()

        let actual = try await window.getAxRect(.nonCancellable).orDie()
        assertEquals(window.isHiddenInCorner, false)
        assertEquals(actual.topLeftCorner, original.topLeftCorner)
        assertEquals(actual.size, original.size)
    }

    func testHidingUsesActualWindowSizeAndPreservesFloatingPosition() async throws {
        let workspace = Workspace.get(byName: name)
        let original = Rect(topLeftX: 100, topLeftY: 100, width: 700, height: 500)
        let window = TestWindow.new(id: 1, parent: workspace.floatingWindowsContainer, rect: original)
        let monitorRect = workspace.workspaceMonitor.visibleRect

        try await window.hideInCorner(.bottomLeftCorner)
        let hidden = try await window.getAxRect(.nonCancellable).orDie()
        assertEquals(hidden.topLeftCorner, CGPoint(x: monitorRect.minX - original.width + 1, y: monitorRect.maxY - 1))
        assertEquals(hidden.size, original.size)

        try await window.hideInCorner(.bottomRightCorner)
        window.unhideFromCorner()
        let restored = try await window.getAxRect(.nonCancellable).orDie()
        assertEquals(restored.topLeftCorner, original.topLeftCorner)
        assertEquals(restored.size, original.size)
    }

    func testHideCornerAvoidsAdjacentDisplays() {
        let monitor = mainMonitorInfo
        let right = VisibilityTestMonitor(rect: Rect(topLeftX: monitor.rect.maxX, topLeftY: 0, width: 1920, height: 1080))
        let left = VisibilityTestMonitor(rect: Rect(topLeftX: -1920, topLeftY: 0, width: 1920, height: 1080))
        assertEquals(monitor.optimalHideCorner(monitors: [monitor, right]), .bottomLeftCorner)
        assertEquals(monitor.optimalHideCorner(monitors: [monitor, left]), .bottomRightCorner)
    }
}

private struct VisibilityTestMonitor: MonitorInfo {
    let rect: Rect
    var visibleRect: Rect { rect }
    var width: CGFloat { rect.width }
    var height: CGFloat { rect.height }
    let monitorAppKitNsScreenScreensId = 2
    let name = "Adjacent monitor"
    let isMain = false
}
