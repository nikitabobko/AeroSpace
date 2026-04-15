@testable import AppBundle
import Common
import XCTest

@MainActor
final class TabsLayoutCommandTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        TabHeaderTitleCache.shared.invalidateAll()
    }

    func testParse() {
        testParseCommandSucc("layout tabs", LayoutCmdArgs(rawArgs: [], toggleBetween: [.tabs]))
    }

    func testSwitchContainerToTabs() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
        }

        let result = try await parseCommand("layout tabs").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(root.layout, .tabs)
        assertEquals(root.layoutDescription, .tabs([.window(1), .window(2)]))
    }

    func testTabsLayoutGeometryKeepsOnlyMostRecentChildVisible() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }
        assertEquals((root.children[1] as! TestWindow).focusWindow(), true)
        root.layout = .tabs

        _ = try await workspace.layoutWorkspace()

        let workspaceRect = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        let activeRect = (root.mostRecentChild as! TestWindow).lastAppliedLayoutPhysicalRect.orDie()
        let expectedHeaderHeight = TabHeaderMetrics.height

        assertEquals(activeRect.topLeftCorner, workspaceRect.topLeftCorner + CGPoint(x: 0, y: expectedHeaderHeight))
        assertEquals(activeRect.width, workspaceRect.width)
        assertEquals(activeRect.height, workspaceRect.height - 1 - expectedHeaderHeight)
        assertNil((root.children[0] as! TestWindow).lastAppliedLayoutPhysicalRect)
    }

    func testTabsLayoutSkipsRedundantFrameUpdates() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
        }
        root.layout = .tabs

        let activeWindow = root.children[1] as! TestWindow
        let inactiveWindow = root.children[0] as! TestWindow

        _ = try await workspace.layoutWorkspace()
        let activeCallsAfterFirstLayout = activeWindow.setAxFrameCalls
        let inactiveCallsAfterFirstLayout = inactiveWindow.setAxFrameCalls

        _ = try await workspace.layoutWorkspace()

        assertEquals(activeWindow.setAxFrameCalls, activeCallsAfterFirstLayout)
        assertEquals(inactiveWindow.setAxFrameCalls, inactiveCallsAfterFirstLayout)
    }

    func testLayoutWorkspaceReturnsTabHeaderSnapshot() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0, title: "Safari")
            assertEquals(TestWindow.new(id: 2, parent: $0, title: "Mail").focusWindow(), true)
            TestWindow.new(id: 3, parent: $0, title: "Notes")
        }
        (root.children[1] as! TestWindow).markAsMostRecentChild()
        root.layout = .tabs

        let snapshots = try await workspace.layoutWorkspace()

        assertEquals(snapshots.count, 1)
        let snapshot = snapshots[0]
        assertEquals(snapshot.items.count, 3)
        assertEquals(snapshot.items.map(\.title), ["Safari", "Mail", "Notes"])
        assertEquals(snapshot.items.count(where: \.isActive), 1)
        assertEquals(snapshot.items.first(where: \.isActive)?.targetWindow.windowId, 2)
        assertEquals(snapshot.headerFrame.height, TabHeaderMetrics.height)
        for item in snapshot.items {
            assert(item.closeButtonFrame.width > 0)
            assert(item.closeButtonFrame.height > 0)
            assert(item.closeButtonFrame.minX >= item.frame.minX)
            assert(item.closeButtonFrame.maxX <= item.frame.maxX)
            assert(item.titleFrame.maxX <= item.closeButtonFrame.minX)
        }
    }

    func testTabHeaderTitleFallbacks() async throws {
        let workspace = Workspace.get(byName: name)
        let appWithoutName = TestNamelessApp()
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0, title: "", app: TestApp.shared)
            TestWindow.new(id: 2, parent: $0, title: "", app: appWithoutName)
        }
        root.layout = .tabs

        let snapshots = try await workspace.layoutWorkspace()
        assertEquals(snapshots.singleOrNil()?.items.map(\.title), [TestApp.shared.name.orDie(), "Window 2"])
    }

    func testTabHeaderInteractionSuppressionWindow() {
        let state = TabHeaderInteractionState.shared
        state.markInteraction()

        assert(state.consumePendingGlobalMouseRefreshSuppression(now: .now))
        assert(!state.consumePendingGlobalMouseRefreshSuppression(now: .now))
    }

    func testTabHeaderInteractionSuppressionExpires() {
        let state = TabHeaderInteractionState.shared
        state.markInteraction()

        assert(!state.consumePendingGlobalMouseRefreshSuppression(now: .now.addingTimeInterval(1)))
    }

    func testCloseInvalidatesCachedTabTitle() async throws {
        let workspace = Workspace.get(byName: name)
        let window = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0, title: "Safari")
        }.children[0] as! TestWindow

        _ = try await window.tabHeaderTitle()
        assertEquals(TabHeaderTitleCache.shared.cachedTitle(for: 1), "Safari")

        window.closeAxWindow()
        assertNil(TabHeaderTitleCache.shared.cachedTitle(for: 1))
    }

    func testTabTitleCacheRefreshesAfterExpiration() async throws {
        let workspace = Workspace.get(byName: name)
        let window = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0, title: "Safari")
        }.children[0] as! TestWindow

        let first = try await TabHeaderTitleCache.shared.title(for: window, now: .distantPast)
        assertEquals(first, "Safari")

        window.setTitleForTests("Safari 2")
        let second = try await TabHeaderTitleCache.shared.title(for: window, now: .now)
        assertEquals(second, "Safari 2")
    }

    func testFocusMovesBetweenTabs() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }
        root.layout = .tabs

        try await FocusCommand.new(direction: .right).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)

        try await FocusCommand.new(direction: .right).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 3)

        try await FocusCommand.new(direction: .left).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testMoveReordersTabs() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }
        root.layout = .tabs

        try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .tabs([.window(1), .window(3), .window(2)]))
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testClosingInactiveTabRemovesItFromSnapshot() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0, title: "Safari").focusWindow(), true)
            TestWindow.new(id: 2, parent: $0, title: "Mail")
            TestWindow.new(id: 3, parent: $0, title: "Notes")
        }
        root.layout = .tabs

        (root.children[2] as! TestWindow).closeAxWindow()
        let snapshots = try await workspace.layoutWorkspace()

        assertEquals(snapshots.count, 1)
        assertEquals(snapshots[0].items.map(\.title), ["Safari", "Mail"])
        assertEquals(snapshots[0].items.first(where: \.isActive)?.targetWindow.windowId, 2)
    }

    func testClosingActiveTabPromotesAnotherTab() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0, title: "Safari")
            assertEquals(TestWindow.new(id: 2, parent: $0, title: "Mail").focusWindow(), true)
            TestWindow.new(id: 3, parent: $0, title: "Notes")
        }
        root.layout = .tabs

        (root.children[1] as! TestWindow).closeAxWindow()
        let snapshots = try await workspace.layoutWorkspace()

        assertEquals(snapshots.count, 1)
        let items = snapshots[0].items
        assertEquals(items.map(\.title), ["Safari", "Notes"])
        assertEquals(items.count(where: \.isActive), 1)
        assert(items.contains(where: { $0.isActive && $0.targetWindow.windowId != 2 }))
    }

    func testClosingLastTabRemovesHeaderSnapshot() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0, title: "Safari")
        }
        root.layout = .tabs

        (root.children[0] as! TestWindow).closeAxWindow()
        let snapshots = try await workspace.layoutWorkspace()

        assertEquals(snapshots.count, 0)
    }
}

private final class TestNamelessApp: AbstractApp {
    let pid: Int32 = 42
    let rawAppBundleId: String? = "test.nameless"
    let name: String? = nil
    let execPath: String? = nil
    let bundlePath: String? = nil

    @MainActor
    func getFocusedWindow() async throws -> Window? { nil }
}
