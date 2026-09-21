@testable import AppBundle
import Common
import XCTest

@MainActor
final class ScrollCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseSingleCommandSucc("scroll left", ScrollCmdArgs(rawArgs: [], direction: .left))
        testParseSingleCommandSucc("scroll right", ScrollCmdArgs(rawArgs: [], direction: .right))
        testParseSingleCommandSucc("layout scrolling", LayoutCmdArgs(rawArgs: [], toggleBetween: [.scrolling]))
    }

    func testSwitchRootToScrolling() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
        }

        let result = await parseCommand("layout scrolling").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(root.layout, .scrolling)
        assertEquals(root.orientation, .h)
        assertEquals(root.scrollingIndex, 0)
    }

    func testRejectNestedScrolling() async {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            }
        }

        let result = await parseCommand("layout scrolling").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["The 'scrolling' layout is only supported for workspace root containers"])
    }

    func testJoiningLastTwoPagesPreservesScrollingRootDuringNormalization() async {
        config.enableNormalizationFlattenContainers = true
        config.enableNormalizationOppositeOrientationForNestedContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.layout = .scrolling
        let first = TestWindow.new(id: 1, parent: root)
        let second = TestWindow.new(id: 2, parent: root)
        assertEquals(first.focusWindow(), true)

        let result = await parseCommand("join-with right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        workspace.normalizeContainers()
        assertEquals(workspace.rootTilingContainer, root)
        assertEquals(root.layoutDescription, .scrolling([.v_tiles([.window(1), .window(2)])]))

        second.closeAxWindow()
        workspace.normalizeContainers()
        assertEquals(workspace.rootTilingContainer, root)
        assertEquals(root.layoutDescription, .scrolling([.window(1)]))
    }

    func testClosingLastOtherPagePreservesTabbedScrollingPage() {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.layout = .scrolling
        let tabs = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tabs, index: INDEX_BIND_LAST)
        TestWindow.new(id: 1, parent: tabs)
        TestWindow.new(id: 2, parent: tabs)
        let otherPage = TestWindow.new(id: 3, parent: root)

        otherPage.closeAxWindow()
        workspace.normalizeContainers()

        assertEquals(workspace.rootTilingContainer, root)
        assertEquals(root.layoutDescription, .scrolling([.tabs([.window(1), .window(2)])]))
    }

    func testScrollingLayoutGeometry() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }
        root.layout = .scrolling
        root.scrollingIndex = 1

        let workspaceRect = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        let pageWidth = workspaceRect.width / 2
        let expectedHeight = workspaceRect.height - 1
        let windows = root.children.compactMap { $0 as? TestWindow }

        // The viewport shows the last two pages, so there is no next page to peek at and the peek reserves
        // nothing. The geometry must be identical whether or not the peek is configured.
        for peekWidth in [0, 40] {
            config.scrollingPeekWidth = peekWidth
            _ = try await workspace.layoutWorkspace()

            // Off-screen pages must be hidden, otherwise their negative/overflow
            // physicalX bleeds onto adjacent monitors.
            XCTAssertNil(windows[0].lastAppliedLayoutPhysicalRect)
            assertEquals(windows[0].isHiddenInCorner, true)

            let rect2 = windows[1].lastAppliedLayoutPhysicalRect.orDie("window 2 should be laid out")
            let rect3 = windows[2].lastAppliedLayoutPhysicalRect.orDie("window 3 should be laid out")

            assertEquals(rect2.topLeftX, workspaceRect.topLeftX)
            assertEquals(rect2.width, pageWidth)
            assertEquals(windows[1].isHiddenInCorner, false)
            assertEquals(rect3.topLeftX, workspaceRect.topLeftX + pageWidth)
            assertEquals(rect3.width, pageWidth)
            assertEquals(rect3.height, expectedHeight)
            assertEquals(rect3.maxX, workspaceRect.maxX)
            assertEquals(windows[2].isHiddenInCorner, false)
        }
    }

    func testScrollingLayoutPeeksAtTheNextPage() async throws {
        config.scrollingPeekWidth = 40
        config.gaps.inner.horizontal = .constant(16)
        config.gaps.outer.right = .constant(12)
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
            TestWindow.new(id: 4, parent: $0)
            TestWindow.new(id: 5, parent: $0)
        }
        root.layout = .scrolling
        root.scrollingIndex = 1

        _ = try await workspace.layoutWorkspace()

        let workspaceRect = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        let rawGap = ResolvedGaps(gaps: config.gaps, monitor: workspace.workspaceMonitor).inner.horizontal.toDouble()
        let peek = CGFloat(config.scrollingPeekWidth)
        let pageWidth = (workspaceRect.width - peek) / 2
        let expectedHeight = workspaceRect.height - 1
        let windows = root.children.compactMap { $0 as? TestWindow }

        // Two full pages plus the peek fill the viewport exactly
        assertEquals(2 * pageWidth + peek, workspaceRect.width)

        for index in [0, 4] {
            XCTAssertNil(windows[index].lastAppliedLayoutPhysicalRect)
            assertEquals(windows[index].isHiddenInCorner, true)
        }

        for index in 1 ... 3 {
            let rect = windows[index].lastAppliedLayoutPhysicalRect.orDie("window \(index + 1) should be laid out")
            let virtual = windows[index].lastAppliedLayoutVirtualRect.orDie()
            let lPadding = index == 1 ? 0 : rawGap / 2
            let rPadding = index == 3 ? 0 : rawGap / 2

            assertEquals(windows[index].isHiddenInCorner, false)
            assertEquals(rect.topLeftX, workspaceRect.topLeftX + CGFloat(index - 1) * pageWidth + lPadding)
            assertEquals(rect.topLeftY, workspaceRect.topLeftY)
            assertEquals(rect.width, pageWidth - lPadding - rPadding)
            assertEquals(rect.height, expectedHeight)

            // Virtual rects stay on the un-gapped page grid, peek page included
            assertEquals(virtual.topLeftX, workspaceRect.topLeftX + CGFloat(index) * pageWidth)
            assertEquals(virtual.width, pageWidth)
        }

        let rightRect = windows[2].lastAppliedLayoutPhysicalRect.orDie()
        let peekRect = windows[3].lastAppliedLayoutPhysicalRect.orDie()
        // The inner gap reduces the visible sliver, while the window also covers the right outer gap.
        assertEquals(workspaceRect.maxX - peekRect.topLeftX, peek - rawGap / 2)
        assertEquals(workspace.workspaceMonitor.visibleRect.maxX - peekRect.topLeftX, 44)
        assertEquals(peekRect.maxX - workspaceRect.maxX, pageWidth - peek)
        assertEquals(peekRect.topLeftX - rightRect.maxX, rawGap)
    }

    func testScrollingLayoutPeekFallsBackToTwoPages() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.layout = .scrolling
        let first = TestWindow.new(id: 1, parent: root)
        let second = TestWindow.new(id: 2, parent: root)
        let third = TestWindow.new(id: 3, parent: root)
        root.scrollingIndex = 0

        let workspaceRect = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        let pageWidth = workspaceRect.width / 2

        // Values that can't produce a sliver plus two pages disable the peek instead of being capped
        for peekWidth in [0, -40, Int(workspaceRect.width / 3) + 1, Int(workspaceRect.width), Int.max] {
            config.scrollingPeekWidth = peekWidth
            _ = try await workspace.layoutWorkspace()

            assertEquals(first.lastAppliedLayoutPhysicalRect.orDie().topLeftX, workspaceRect.topLeftX)
            assertEquals(first.lastAppliedLayoutPhysicalRect.orDie().width, pageWidth)
            assertEquals(second.lastAppliedLayoutPhysicalRect.orDie().topLeftX, workspaceRect.topLeftX + pageWidth)
            assertEquals(second.lastAppliedLayoutPhysicalRect.orDie().width, pageWidth)
            assertEquals(first.isHiddenInCorner, false)
            assertEquals(second.isHiddenInCorner, false)
            assertEquals(third.isHiddenInCorner, true)
            XCTAssertNil(third.lastAppliedLayoutPhysicalRect)
        }

        // A valid peek still reserves nothing when there is no next page to peek at
        third.closeAxWindow()
        config.scrollingPeekWidth = 40
        _ = try await workspace.layoutWorkspace()

        assertEquals(root.children.count, 2)
        assertEquals(first.lastAppliedLayoutPhysicalRect.orDie().width, pageWidth)
        assertEquals(second.lastAppliedLayoutPhysicalRect.orDie().width, pageWidth)
        assertEquals(second.lastAppliedLayoutPhysicalRect.orDie().maxX, workspaceRect.maxX)
    }

    func testScrollingPeekFallsBackWhenGapsLeaveNoRoom() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.layout = .scrolling
        TestWindow.new(id: 1, parent: root)
        let second = TestWindow.new(id: 2, parent: root)
        let third = TestWindow.new(id: 3, parent: root)
        let viewport = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        let largeGap = Int(viewport.width * 0.6)

        for (gap, peek, isVisible) in [(-1, 40, false), (79, 40, true), (80, 40, false), (largeGap, largeGap / 2 + 1, false)] {
            config.gaps.inner.horizontal = .constant(gap)
            config.scrollingPeekWidth = peek
            _ = try await workspace.layoutWorkspace()

            assertEquals(third.isHiddenInCorner, !isVisible)
            if isVisible {
                assertEquals(third.lastAppliedLayoutPhysicalRect.orDie().topLeftX, viewport.maxX - 0.5)
            } else {
                XCTAssertNil(third.lastAppliedLayoutPhysicalRect)
                assertEquals(second.lastAppliedLayoutPhysicalRect.orDie().maxX, viewport.maxX)
            }
        }
    }

    func testFocusingPeekPageFullyRevealsIt() async throws {
        config.scrollingPeekWidth = 40
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.layout = .scrolling
        let first = TestWindow.new(id: 1, parent: root)
        TestWindow.new(id: 2, parent: root)
        let third = TestWindow.new(id: 3, parent: root)
        assertEquals(first.focusWindow(), true)
        _ = try await workspace.layoutWorkspace()
        let viewport = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        XCTAssertGreaterThan(third.lastAppliedLayoutPhysicalRect.orDie().maxX, viewport.maxX)

        assertEquals(third.focusWindow(), true)
        _ = try await workspace.layoutWorkspace()

        assertEquals(root.scrollingIndex, 1)
        assertEquals(first.isHiddenInCorner, true)
        let rect = third.lastAppliedLayoutPhysicalRect.orDie()
        assertEquals(rect.maxX, viewport.maxX)
        assertEquals(rect.width, viewport.width / 2)
    }

    func testScrollCommandsMoveViewportAndFocus() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
            TestWindow.new(id: 4, parent: $0)
        }
        root.layout = .scrolling
        assertEquals((root.children[1] as! Window).focusWindow(), true)
        assertEquals(root.scrollingIndex, 0)

        let scrollRight = await parseCommand("scroll right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(scrollRight.exitCode.rawValue, 0)
        assertEquals(root.scrollingIndex, 1)
        assertEquals(focus.windowOrNil?.windowId, 3)

        await parseCommand("scroll right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.scrollingIndex, 2)
        assertEquals(focus.windowOrNil?.windowId, 4)

        await parseCommand("scroll right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.scrollingIndex, 2)
        assertEquals(focus.windowOrNil?.windowId, 4)

        await parseCommand("scroll left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.scrollingIndex, 1)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testMoveCommandKeepsFocusedWindowVisible() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
            TestWindow.new(id: 4, parent: $0)
        }
        root.layout = .scrolling
        assertEquals((root.children[2] as! Window).focusWindow(), true)
        assertEquals(root.scrollingIndex, 1)

        let result = await parseCommand("move right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(root.layoutDescription, .scrolling([.window(1), .window(2), .window(4), .window(3)]))
        assertEquals(root.scrollingIndex, 2)
        assertEquals(focus.windowOrNil?.windowId, 3)
    }

    func testFocusedWindowAutoRevealsNewestPage() {
        let root = Workspace.get(byName: name).rootTilingContainer
        root.layout = .scrolling

        assertEquals(TestWindow.new(id: 1, parent: root).focusWindow(), true)
        assertEquals(root.scrollingIndex, 0)

        assertEquals(TestWindow.new(id: 2, parent: root).focusWindow(), true)
        assertEquals(root.scrollingIndex, 0)

        assertEquals(TestWindow.new(id: 3, parent: root).focusWindow(), true)
        assertEquals(root.scrollingIndex, 1)

        assertEquals(TestWindow.new(id: 4, parent: root).focusWindow(), true)
        assertEquals(root.scrollingIndex, 2)
    }

    func testClosingClampsScrollingIndex() {
        let root = Workspace.get(byName: name).rootTilingContainer
        root.layout = .scrolling
        let w1 = TestWindow.new(id: 1, parent: root)
        let w2 = TestWindow.new(id: 2, parent: root)
        let w3 = TestWindow.new(id: 3, parent: root)
        let w4 = TestWindow.new(id: 4, parent: root)
        _ = [w1, w2, w3]
        root.scrollingIndex = 2

        w4.closeAxWindow()
        assertEquals(root.scrollingIndex, 1)
    }

    func testResizeAndBalanceSizesFailInScrollingLayout() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }
        root.layout = .scrolling

        let resizeResult = await parseCommand("resize smart +10").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(resizeResult.exitCode.rawValue, 2)
        assertEquals(resizeResult.stderr, ["resize command doesn't support the scrolling layout"])

        let balanceResult = await parseCommand("balance-sizes").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(balanceResult.exitCode.rawValue, 2)
        assertEquals(balanceResult.stderr, ["balance-sizes command doesn't support the scrolling layout"])
    }

    func testWindowLayoutFormattingReportsScrolling() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            let nested = TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1)
            TestWindow.new(id: 1, parent: nested)
            TestWindow.new(id: 2, parent: $0)
        }
        root.layout = .scrolling

        let windows = root.allLeafWindowsRecursive.map { AeroObj.window(.forTest(window: $0, title: "w\($0.windowId)")) }
        assertSucc(windows.format([.interVar(.formatVar(.window(.windowLayout)))]), ["scrolling", "scrolling"])
    }
}
