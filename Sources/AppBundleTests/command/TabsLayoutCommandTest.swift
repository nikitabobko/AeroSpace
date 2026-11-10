@testable import AppBundle
import Common
import Foundation
import Testing

@MainActor
@Suite(.serializedGlobally)
struct TabsLayoutCommandTest {
    init() {
        setUpWorkspacesForTests()
        TabHeaderTitleCache.shared.invalidateAll()
    }

    @Test func testParse() {
        testParseSingleCommandSucc("layout tabs", LayoutCmdArgs(rawArgs: [], toggleBetween: [.tabs]))
    }

    @Test func testSwitchContainerToTabs() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
        }

        let result = await parseCommand("layout tabs").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(root.layout, .tabs)
        assertEquals(root.layoutDescription, .tabs([.window(1), .window(2)]))
    }

    @Test func testTabsLayoutGeometryKeepsOnlyMostRecentChildVisible() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }
        assertEquals((root.children[1] as! TestWindow).focusWindow(), true)
        root.layout = .tabs

        _ = try await workspace.layoutWorkspace()

        let workspaceRect = workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps
        let activeRect = (root.mostRecentChild as! TestWindow).lastAppliedLayoutPhysicalRect.orDie()
        let expectedHeaderHeight = TabHeaderMetrics.height

        assertEquals(activeRect.topLeftCorner, workspaceRect.topLeftCorner + CGPoint(x: 0, y: expectedHeaderHeight))
        assertEquals(activeRect.width, workspaceRect.width)
        assertEquals(activeRect.height, workspaceRect.height - 1 - expectedHeaderHeight)
        assertNil((root.children[0] as! TestWindow).lastAppliedLayoutPhysicalRect)
    }

    @Test func testTabsSkipNativeTabTombstones() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.layout = .tabs
        let page = TilingContainer.newHTiles(parent: root, adaptiveWeight: 1)
        let active = TestWindow.new(id: 1, parent: page)
        let inactive = TestWindow.new(id: 2, parent: page)
        inactive.lifeStatus = .invisible
        let dead = TestWindow.new(id: 3, parent: root)
        dead.lifeStatus = .dead

        let snapshots = try await workspace.layoutWorkspace()

        assertEquals(snapshots.count, 1)
        assertEquals(snapshots[0].items.count, 1)
        assertEquals(snapshots[0].items[0].targetWindow, active)
        assertEquals(snapshots[0].items[0].isActive, true)
        assertNotNil(active.lastAppliedLayoutPhysicalRect)
        assertNil(inactive.lastAppliedLayoutPhysicalRect)
        assertNil(dead.lastAppliedLayoutPhysicalRect)
    }

    @Test func testLayoutRestoresWindowsMovedOutsideTheLayout() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }
        for layout: Layout in [.tiles, .tabs, .scrolling] {
            root.layout = layout
            _ = try await workspace.layoutWorkspace()
            var expectedFrames: [Rect] = []
            for window in root.children.compactMap({ $0 as? TestWindow }) {
                let rect = try await window.getAxRect(.nonCancellable).orDie()
                expectedFrames.append(rect)
                // Simulate an app or a workspace transition moving the actual window.
                window.setAxFrame(rect.topLeftCorner + CGPoint(x: 100, y: 100), rect.size)
            }

            _ = try await workspace.layoutWorkspace()

            for (window, expected) in zip(root.children.compactMap { $0 as? TestWindow }, expectedFrames) {
                let actual = try await window.getAxRect(.nonCancellable).orDie()
                assertEquals(actual.topLeftCorner, expected.topLeftCorner)
                assertEquals(actual.size, expected.size)
            }
        }
    }

    @Test func testLayoutWorkspaceReturnsTabHeaderSnapshot() async throws {
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

    @Test func testTabHeaderTitleFallbacks() async throws {
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

    @Test func testTabHeaderInteractionSuppressionWindow() {
        let state = TabHeaderInteractionState.shared
        state.markInteraction()

        assert(state.consumePendingGlobalMouseRefreshSuppression(now: .now))
        assert(!state.consumePendingGlobalMouseRefreshSuppression(now: .now))
    }

    @Test func testTabHeaderInteractionSuppressionExpires() {
        let state = TabHeaderInteractionState.shared
        state.markInteraction()

        assert(!state.consumePendingGlobalMouseRefreshSuppression(now: .now.addingTimeInterval(1)))
    }

    @Test func testCloseInvalidatesCachedTabTitle() async throws {
        let workspace = Workspace.get(byName: name)
        let window = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0, title: "Safari")
        }.children[0] as! TestWindow

        _ = try await window.tabHeaderTitle()
        assertEquals(TabHeaderTitleCache.shared.cachedTitle(for: 1), "Safari")

        window.closeAxWindow()
        assertNil(TabHeaderTitleCache.shared.cachedTitle(for: 1))
    }

    @Test func testTabTitleCacheRefreshesAfterExpiration() async throws {
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

    @Test func testFocusMovesBetweenTabs() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }
        root.layout = .tabs

        await FocusCommand.new(direction: .right).run(.defaultEnv, .emptyStdin)
        assertEquals(globalFocus.windowOrNil?.windowId, 2)

        await FocusCommand.new(direction: .right).run(.defaultEnv, .emptyStdin)
        assertEquals(globalFocus.windowOrNil?.windowId, 3)

        await FocusCommand.new(direction: .left).run(.defaultEnv, .emptyStdin)
        assertEquals(globalFocus.windowOrNil?.windowId, 2)
    }

    @Test func testMoveReordersTabs() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }
        root.layout = .tabs

        await parseCommand("move right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .tabs([.window(1), .window(3), .window(2)]))
        assertEquals(globalFocus.windowOrNil?.windowId, 2)
    }

    @Test func testClosingInactiveTabRemovesItFromSnapshot() async throws {
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

    @Test func testClosingActiveTabPromotesAnotherTab() async throws {
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

    @Test func testClosingLastTabRemovesHeaderSnapshot() async throws {
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
    func getFocusedWindow(_ cm: CancellationMode) async throws -> Window? { nil }
}
