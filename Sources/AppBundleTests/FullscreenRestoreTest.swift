@testable import AppBundle
import Common
import XCTest

@MainActor
final class FullscreenRestoreTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    /// Bug repro: when a window exits macOS native fullscreen, it should be restored
    /// to the same nested tiling container at the same slot it came from -- not
    /// dumped at the end of the workspace's root tiling container.
    func testExitFullscreenRestoresWindowToOriginalNestedContainer() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let vSplit = TilingContainer.newVTiles(parent: root, adaptiveWeight: 1)

        _ = TestWindow.new(id: 1, parent: root)
        _ = TestWindow.new(id: 2, parent: vSplit)
        let videoWin = TestWindow.new(id: 3, parent: vSplit)
        _ = TestWindow.new(id: 4, parent: root)

        videoWin.markAsMostRecentChild()

        XCTAssertTrue(videoWin.parent === vSplit)
        XCTAssertEqual(vSplit.children.count, 2)
        XCTAssertEqual(root.children.count, 3)

        // Capture prev binding (mirrors enterMacOsUnconventionalState).
        let prev = MacosPrev(parent: videoWin.parent!, index: videoWin.ownIndex!, adaptiveWeight: 1)
        videoWin.layoutReason = .macos(prev: prev)
        videoWin.bind(
            to: workspace.macOsNativeFullscreenWindowsContainer,
            adaptiveWeight: WEIGHT_DOESNT_MATTER,
            index: INDEX_BIND_LAST,
        )

        try await exitMacOsNativeUnconventionalState(window: videoWin, prev: prev, workspace: workspace)

        XCTAssertTrue(
            videoWin.parent === vSplit,
            "videoWin should be restored to vSplit, but parent is \(String(describing: videoWin.parent))",
        )
        XCTAssertEqual(vSplit.children.count, 2)
        XCTAssertEqual(root.children.count, 3)
        XCTAssertEqual(videoWin.ownIndex, 1, "videoWin should be at its original slot inside vSplit")
    }

    /// When the original parent has been gc'd (e.g. its only sibling was closed
    /// while the window was fullscreen), we must fall back gracefully instead of
    /// crashing or losing the window.
    func testExitFullscreenFallsBackWhenPrevParentGone() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let vSplit = TilingContainer.newVTiles(parent: root, adaptiveWeight: 1)

        let neighbor = TestWindow.new(id: 1, parent: vSplit)
        let videoWin = TestWindow.new(id: 2, parent: vSplit)
        _ = TestWindow.new(id: 3, parent: root)

        let prev = MacosPrev(parent: videoWin.parent!, index: videoWin.ownIndex!, adaptiveWeight: 1)
        videoWin.layoutReason = .macos(prev: prev)
        videoWin.bind(
            to: workspace.macOsNativeFullscreenWindowsContainer,
            adaptiveWeight: WEIGHT_DOESNT_MATTER,
            index: INDEX_BIND_LAST,
        )

        // Simulate vSplit being emptied and gc'd while fullscreen is active.
        // (We can't release the strong test-local reference, but unbinding vSplit
        // clears its workspace -- which is what the production check looks at.)
        neighbor.unbindFromParent()
        vSplit.unbindFromParent()
        XCTAssertNil(vSplit.nodeWorkspace, "unbound vSplit must no longer belong to any workspace")

        try await exitMacOsNativeUnconventionalState(window: videoWin, prev: prev, workspace: workspace)

        XCTAssertNotNil(videoWin.parent, "videoWin must be re-bound somewhere")
        XCTAssertTrue(videoWin.nodeWorkspace === workspace, "videoWin must stay in the same workspace")
        XCTAssertFalse(videoWin.parent === vSplit, "videoWin must not land in the gc'd container")
    }

    /// Three-window flat horizontal tile: fullscreen the middle one and exit.
    /// It must land back at index 1, not index 2 (end). This reproduces the
    /// "swap + fullscreen toggle moves YouTube to the right" bug.
    func testExitFullscreenPreservesMiddlePositionInFlatTile() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer

        let left = TestWindow.new(id: 1, parent: root)
        let middle = TestWindow.new(id: 2, parent: root)
        let right = TestWindow.new(id: 3, parent: root)

        XCTAssertEqual(middle.ownIndex, 1)

        // Enter fullscreen.
        let prev = MacosPrev(parent: middle.parent!, index: middle.ownIndex!, adaptiveWeight: 1)
        middle.layoutReason = .macos(prev: prev)
        middle.bind(
            to: workspace.macOsNativeFullscreenWindowsContainer,
            adaptiveWeight: WEIGHT_DOESNT_MATTER,
            index: INDEX_BIND_LAST,
        )
        XCTAssertEqual(root.children.count, 2, "Mid: root has [left, right] while middle is fullscreen")

        // Exit fullscreen.
        try await exitMacOsNativeUnconventionalState(window: middle, prev: prev, workspace: workspace)

        XCTAssertTrue(middle.parent === root)
        XCTAssertEqual(root.children.count, 3)
        XCTAssertEqual(middle.ownIndex, 1, "middle must be restored to its original index 1, not pushed to the end")
        XCTAssertEqual(left.ownIndex, 0)
        XCTAssertEqual(right.ownIndex, 2)
    }

    /// Same as above, but enter fullscreen on the LAST window (index 2). It
    /// must also land back at index 2, not collapse to index 1.
    func testExitFullscreenPreservesLastPositionInFlatTile() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer

        _ = TestWindow.new(id: 1, parent: root)
        _ = TestWindow.new(id: 2, parent: root)
        let last = TestWindow.new(id: 3, parent: root)

        let prev = MacosPrev(parent: last.parent!, index: last.ownIndex!, adaptiveWeight: 1)
        last.layoutReason = .macos(prev: prev)
        last.bind(
            to: workspace.macOsNativeFullscreenWindowsContainer,
            adaptiveWeight: WEIGHT_DOESNT_MATTER,
            index: INDEX_BIND_LAST,
        )

        try await exitMacOsNativeUnconventionalState(window: last, prev: prev, workspace: workspace)

        XCTAssertEqual(last.ownIndex, 2, "last must come back at index 2")
        XCTAssertEqual(root.children.count, 3)
    }

    /// User scenario: 3 windows tiled, then user swaps the middle one. Fullscreen
    /// it, exit. It must return to its post-swap position, not to its pre-swap
    /// position. A sibling getting briefly gc'd during the fullscreen must not
    /// scramble the order on exit.
    func testExitFullscreenRestoresMiddleAfterSiblingShifts() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer

        let left = TestWindow.new(id: 100, parent: root)
        let target = TestWindow.new(id: 200, parent: root)
        let rightSibling = TestWindow.new(id: 300, parent: root)

        let prev = MacosPrev(parent: target.parent!, index: target.ownIndex!, adaptiveWeight: 1)
        target.layoutReason = .macos(prev: prev)
        target.bind(
            to: workspace.macOsNativeFullscreenWindowsContainer,
            adaptiveWeight: WEIGHT_DOESNT_MATTER,
            index: INDEX_BIND_LAST,
        )

        // Simulate the right sibling getting briefly gc'd while target is fullscreen.
        rightSibling.unbindFromParent()
        XCTAssertEqual(root.children.count, 1)

        try await exitMacOsNativeUnconventionalState(window: target, prev: prev, workspace: workspace)

        // At this moment, root = [left, target]. The right sibling comes back next.
        XCTAssertEqual(target.ownIndex, 1)
        rightSibling.bind(to: root, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        XCTAssertEqual(root.children.count, 3)
        // Final visual must match the pre-fullscreen order, NOT [left, rightSibling, target].
        XCTAssertEqual(left.ownIndex, 0)
        XCTAssertEqual(target.ownIndex, 1, "target must remain at its original middle index")
        XCTAssertEqual(rightSibling.ownIndex, 2)
    }

    /// The reverse order: right sibling re-binds BEFORE we exit fullscreen.
    /// Anchors must place target back between left and rightSibling.
    func testExitFullscreenPreservesOrderWhenSiblingReturnsFirst() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer

        let left = TestWindow.new(id: 100, parent: root)
        let target = TestWindow.new(id: 200, parent: root)
        let rightSibling = TestWindow.new(id: 300, parent: root)

        let prev = MacosPrev(parent: target.parent!, index: target.ownIndex!, adaptiveWeight: 1)
        target.layoutReason = .macos(prev: prev)
        target.bind(
            to: workspace.macOsNativeFullscreenWindowsContainer,
            adaptiveWeight: WEIGHT_DOESNT_MATTER,
            index: INDEX_BIND_LAST,
        )

        // Right sibling briefly gc'd and rebound -- but rebound BEFORE we exit.
        rightSibling.unbindFromParent()
        rightSibling.bind(to: root, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        XCTAssertEqual(root.children.count, 2) // [left, rightSibling]

        try await exitMacOsNativeUnconventionalState(window: target, prev: prev, workspace: workspace)

        XCTAssertEqual(root.children.count, 3)
        XCTAssertEqual(left.ownIndex, 0)
        XCTAssertEqual(target.ownIndex, 1, "target must land between left and rightSibling, not at the end")
        XCTAssertEqual(rightSibling.ownIndex, 2)
    }

    /// Single-window workspace -- the simple case must still work after the fix.
    func testExitFullscreenSingleWindow() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let videoWin = TestWindow.new(id: 1, parent: root)

        let prev = MacosPrev(parent: videoWin.parent!, index: videoWin.ownIndex!, adaptiveWeight: 1)
        videoWin.layoutReason = .macos(prev: prev)
        videoWin.bind(
            to: workspace.macOsNativeFullscreenWindowsContainer,
            adaptiveWeight: WEIGHT_DOESNT_MATTER,
            index: INDEX_BIND_LAST,
        )

        try await exitMacOsNativeUnconventionalState(window: videoWin, prev: prev, workspace: workspace)

        XCTAssertTrue(videoWin.parent === root, "single window should land back in root tiling container")
    }
}
