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
