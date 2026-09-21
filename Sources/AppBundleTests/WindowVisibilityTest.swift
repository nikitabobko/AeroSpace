@testable import AppBundle
import Common
import XCTest

@MainActor
final class WindowVisibilityTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testPeekPageRestoresWhenMadeFloating() async throws {
        config.scrollingPeekWidth = 40
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.layout = .scrolling
        let first = TestWindow.new(id: 1, parent: root)
        TestWindow.new(id: 2, parent: root)
        let third = TestWindow.new(id: 3, parent: root)
        assertEquals(first.focusWindow(), true)
        _ = try await workspace.layoutWorkspace()

        let result = await parseCommand("layout --window-id 3 floating").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(third.focusWindow(), true)
        _ = try await workspace.layoutWorkspace()

        let rect = try await third.getAxRect(.nonCancellable).orDie()
        let viewport = workspace.workspaceMonitor.visibleRect
        assertEquals(third.isFloating, true)
        XCTAssertGreaterThanOrEqual(rect.minX, viewport.minX)
        XCTAssertLessThanOrEqual(rect.maxX, viewport.maxX)
        assertEquals(viewport.contains(rect.center), true)
    }

    func testNewDialogFollowsAppWindowOnAnotherWorkspace() async {
        let ownerWorkspace = Workspace.get(byName: "owner")
        let owner = TestWindow.new(id: 1, parent: ownerWorkspace.rootTilingContainer)
        let activeWorkspace = Workspace.get(byName: "current")
        assertEquals(TestWindow.new(id: 2, parent: activeWorkspace.rootTilingContainer).focusWindow(), true)

        let binding = unbindAndGetBindingDataForNewWindow(.dialog, activeWorkspace, window: nil, appLastFocusedWindow: owner)
        let dialog = TestWindow.new(id: 3, parent: binding.parent)
        assertEquals(dialog.nodeWorkspace, ownerWorkspace)
        assertEquals(dialog.isFloating, true)
        assertEquals(focus.workspace, activeWorkspace)

        // Explicit user callbacks must still be able to override the default placement.
        config.onWindowDetected = [WindowDetectedCallback(matcher: .command(.empty), rawRun: parseCommand("move-node-to-workspace current").cmdOrDie)]
        await tryOnWindowDetected(dialog)
        assertEquals(dialog.nodeWorkspace, activeWorkspace)
    }

    func testDialogWithoutKnownOwnerUsesCurrentWorkspace() {
        let workspace = Workspace.get(byName: name)
        let binding = unbindAndGetBindingDataForNewWindow(.dialog, workspace, window: nil, appLastFocusedWindow: nil)
        assertEquals(binding.parent, workspace.floatingWindowsContainer)
    }

    func testDialogRelayoutKeepsExplicitTargetWorkspace() {
        let ownerWorkspace = Workspace.get(byName: "owner")
        let owner = TestWindow.new(id: 1, parent: ownerWorkspace.rootTilingContainer)
        let dialog = TestWindow.new(id: 2, parent: ownerWorkspace.floatingWindowsContainer)
        let targetWorkspace = Workspace.get(byName: "destination")

        let binding = unbindAndGetBindingDataForNewWindow(.dialog, targetWorkspace, window: dialog, appLastFocusedWindow: owner)

        assertEquals(binding.parent, targetWorkspace.floatingWindowsContainer)
    }

    func testNewRegularWindowStillUsesCurrentWorkspace() {
        let ownerWorkspace = Workspace.get(byName: "owner")
        let owner = TestWindow.new(id: 1, parent: ownerWorkspace.rootTilingContainer)
        let workspace = Workspace.get(byName: name)

        let binding = unbindAndGetBindingDataForNewWindow(.window, workspace, window: nil, appLastFocusedWindow: owner)

        assertEquals(binding.parent, workspace.rootTilingContainer)
    }

    func testOffscreenFloatingDialogsOnActiveWorkspaceAreRecoveredWithoutTakingFocus() async throws {
        let workspace = Workspace.get(byName: name)
        let focusedWindow = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(focusedWindow.focusWindow(), true)
        let monitorRect = workspace.workspaceMonitor.visibleRect
        let size = CGSize(width: 600, height: 400)
        let origins = [
            CGPoint(x: monitorRect.minX - size.width + 20, y: monitorRect.minY),
            CGPoint(x: monitorRect.maxX - 20, y: monitorRect.minY),
            CGPoint(x: monitorRect.minX, y: monitorRect.minY - size.height + 20),
            CGPoint(x: monitorRect.minX, y: monitorRect.maxY - 20),
            CGPoint(x: -20000, y: -20000),
        ]
        for (index, origin) in origins.enumerated() {
            let dialog = TestWindow.new(
                id: UInt32(index + 2),
                parent: workspace.floatingWindowsContainer,
                rect: Rect(topLeftX: origin.x, topLeftY: origin.y, width: size.width, height: size.height),
            )

            _ = try await workspace.layoutWorkspace()

            let actual = try await dialog.getAxRect(.nonCancellable).orDie()
            assertEquals(actual.size, size)
            XCTAssertGreaterThanOrEqual(actual.minX, monitorRect.minX)
            XCTAssertGreaterThanOrEqual(actual.minY, monitorRect.minY)
            XCTAssertLessThanOrEqual(actual.maxX, monitorRect.maxX)
            XCTAssertLessThanOrEqual(actual.maxY, monitorRect.maxY)
            assertEquals(focus.windowOrNil, focusedWindow)
        }
    }

    func testFloatingWindowWithVisibleCenterKeepsItsPosition() async throws {
        let workspace = Workspace.get(byName: name)
        assertEquals(workspace.focusWorkspace(), true)
        let original = Rect(topLeftX: -20, topLeftY: 100, width: 600, height: 400)
        let window = TestWindow.new(id: 1, parent: workspace.floatingWindowsContainer, rect: original)

        _ = try await workspace.layoutWorkspace()

        let actual = try await window.getAxRect(.nonCancellable).orDie()
        assertEquals(actual.topLeftCorner, original.topLeftCorner)
        assertEquals(actual.size, original.size)
    }

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

    func testPeekPageIsLaidOutInsteadOfHiddenAndStillRestores() async throws {
        config.scrollingPeekWidth = 40
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.layout = .scrolling
        let tabs = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tabs, index: INDEX_BIND_LAST)
        let inactiveTab = TestWindow.new(id: 1, parent: tabs)
        let activeTab = TestWindow.new(id: 2, parent: tabs)
        let rightPage = TestWindow.new(id: 3, parent: root)
        let peekPage = TestWindow.new(id: 4, parent: root)
        let parkedPage = TestWindow.new(id: 5, parent: root)
        assertEquals(activeTab.focusWindow(), true)
        root.scrollingIndex = 0

        _ = try await workspace.layoutWorkspace()

        // The peek page is laid out, only the page behind it is parked off-screen
        assertEquals(activeTab.isHiddenInCorner, false)
        assertEquals(inactiveTab.isHiddenInCorner, true)
        assertEquals(rightPage.isHiddenInCorner, false)
        assertEquals(peekPage.isHiddenInCorner, false)
        assertEquals(parkedPage.isHiddenInCorner, true)
        XCTAssertNil(parkedPage.lastAppliedLayoutPhysicalRect)

        let parkedSize = try await parkedPage.getAxSize(.nonCancellable)
        let corner = workspace.workspaceMonitor.optimalHideCorner(monitors: monitorInfos)
        for window in workspace.allLeafWindowsRecursive {
            try await window.hideInCorner(corner)
        }
        _ = try await workspace.layoutWorkspace()

        // A parked page keeps its saved size, a peek page is restored just like a fully visible one
        assertEquals(peekPage.isHiddenInCorner, false)
        assertEquals(parkedPage.isHiddenInCorner, true)
        assertEquals(try await parkedPage.getAxSize(.nonCancellable), parkedSize)

        root.scrollingIndex = 1
        _ = try await workspace.layoutWorkspace()
        assertEquals(activeTab.isHiddenInCorner, true)
        assertEquals(rightPage.isHiddenInCorner, false)
        assertEquals(peekPage.isHiddenInCorner, false)
        assertEquals(parkedPage.isHiddenInCorner, false) // Now the peek page

        root.scrollingIndex = 0
        _ = try await workspace.layoutWorkspace()
        assertEquals(parkedPage.isHiddenInCorner, true)
        XCTAssertNil(parkedPage.lastAppliedLayoutPhysicalRect)

        // Disabling the window manager must restore every page, peeking or parked, onto the monitor
        let wasEnabled = TrayMenuModel.shared.isEnabled
        defer { TrayMenuModel.shared.isEnabled = wasEnabled }
        TrayMenuModel.shared.isEnabled = false
        _ = try await workspace.layoutWorkspace()
        for window in workspace.allLeafWindowsRecursive {
            assertEquals(window.isHiddenInCorner, false)
            let rect = try await window.getAxRect(.nonCancellable).orDie()
            assertEquals(workspace.workspaceMonitor.visibleRect.contains(rect.center), true)
        }
    }

    func testRightSpillBandSuppressesScrollingPeek() {
        let monitor = mainMonitorInfo
        let rect = monitor.rect
        func at(x: CGFloat, y: CGFloat) -> VisibilityTestMonitor {
            VisibilityTestMonitor(rect: Rect(topLeftX: x, topLeftY: y, width: rect.width, height: rect.height))
        }
        let right = at(x: rect.maxX, y: rect.minY)
        let left = at(x: rect.minX - rect.width, y: rect.minY)
        let distantRight = at(x: rect.maxX + 10000, y: rect.minY)
        let partiallyOverlappingRight = at(x: rect.maxX, y: rect.minY - rect.height + 1)
        let aboveRight = at(x: rect.maxX, y: rect.minY - rect.height)
        let belowRight = at(x: rect.maxX, y: rect.maxY)
        let straddlingRight = at(x: rect.maxX - 10, y: rect.minY)

        assertEquals(monitor.hasMonitorInRightSpillBand(monitors: []), false)
        assertEquals(monitor.hasMonitorInRightSpillBand(monitors: [monitor]), false)
        assertEquals(monitor.hasMonitorInRightSpillBand(monitors: [monitor, right]), true)
        assertEquals(monitor.hasMonitorInRightSpillBand(monitors: [monitor, left]), false)
        assertEquals(monitor.hasMonitorInRightSpillBand(monitors: [monitor, left, right]), true)
        // Distance doesn't make a right hand side monitor safe: apps may refuse the requested width
        assertEquals(monitor.hasMonitorInRightSpillBand(monitors: [monitor, distantRight]), true)
        // One point of vertical overlap is enough, but merely touching the band's edge isn't
        assertEquals(monitor.hasMonitorInRightSpillBand(monitors: [monitor, partiallyOverlappingRight]), true)
        assertEquals(monitor.hasMonitorInRightSpillBand(monitors: [monitor, straddlingRight]), true)
        assertEquals(monitor.hasMonitorInRightSpillBand(monitors: [monitor, aboveRight]), false)
        assertEquals(monitor.hasMonitorInRightSpillBand(monitors: [monitor, belowRight]), false)
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
