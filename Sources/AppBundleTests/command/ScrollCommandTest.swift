@testable import AppBundle
import Common
import XCTest

@MainActor
final class ScrollCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseCommandSucc("scroll left", ScrollCmdArgs(rawArgs: [], direction: .left))
        testParseCommandSucc("scroll right", ScrollCmdArgs(rawArgs: [], direction: .right))
        testParseCommandSucc("layout scrolling", LayoutCmdArgs(rawArgs: [], toggleBetween: [.scrolling]))
    }

    func testSwitchRootToScrolling() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
        }

        let result = try await parseCommand("layout scrolling").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(root.layout, .scrolling)
        assertEquals(root.orientation, .h)
        assertEquals(root.scrollingIndex, 0)
    }

    func testRejectNestedScrolling() async throws {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            }
        }

        let result = try await parseCommand("layout scrolling").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["The 'scrolling' layout is only supported for workspace root containers"])
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

        _ = try await workspace.layoutWorkspace()

        let workspaceRect = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        let pageWidth = workspaceRect.width / 2
        let expectedHeight = workspaceRect.height - 1
        let windows = root.children.compactMap { $0 as? TestWindow }

        let rect1 = windows[0].lastAppliedLayoutPhysicalRect.orDie("window 1 should be laid out")
        let rect2 = windows[1].lastAppliedLayoutPhysicalRect.orDie("window 2 should be laid out")
        let rect3 = windows[2].lastAppliedLayoutPhysicalRect.orDie("window 3 should be laid out")

        assertEquals(rect1.topLeftX, workspaceRect.topLeftX - pageWidth)
        assertEquals(rect1.width, pageWidth)
        assertEquals(rect2.topLeftX, workspaceRect.topLeftX)
        assertEquals(rect2.width, pageWidth)
        assertEquals(rect3.topLeftX, workspaceRect.topLeftX + pageWidth)
        assertEquals(rect3.width, pageWidth)
        assertEquals(rect3.height, expectedHeight)
    }

    func testScrollCommandsMoveViewportAndFocus() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
            TestWindow.new(id: 4, parent: $0)
        }
        root.layout = .scrolling
        assertEquals((root.children[1] as! Window).focusWindow(), true)
        assertEquals(root.scrollingIndex, 0)

        let scrollRight = try await parseCommand("scroll right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(scrollRight.exitCode.rawValue, 0)
        assertEquals(root.scrollingIndex, 1)
        assertEquals(focus.windowOrNil?.windowId, 3)

        try await parseCommand("scroll right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.scrollingIndex, 2)
        assertEquals(focus.windowOrNil?.windowId, 4)

        try await parseCommand("scroll right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.scrollingIndex, 2)
        assertEquals(focus.windowOrNil?.windowId, 4)

        try await parseCommand("scroll left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.scrollingIndex, 1)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testMoveCommandKeepsFocusedWindowVisible() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
            TestWindow.new(id: 4, parent: $0)
        }
        root.layout = .scrolling
        assertEquals((root.children[2] as! Window).focusWindow(), true)
        assertEquals(root.scrollingIndex, 1)

        let result = try await parseCommand("move right").cmdOrDie.run(.defaultEnv, .emptyStdin)
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

    func testResizeAndBalanceSizesFailInScrollingLayout() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }
        root.layout = .scrolling

        let resizeResult = try await parseCommand("resize smart +10").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(resizeResult.exitCode.rawValue, 2)
        assertEquals(resizeResult.stderr, ["resize command doesn't support the scrolling layout"])

        let balanceResult = try await parseCommand("balance-sizes").cmdOrDie.run(.defaultEnv, .emptyStdin)
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
        assertSucc(windows.format([.interVar("window-layout")]), ["scrolling", "scrolling"])
    }
}
