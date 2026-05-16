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

    /// Reproduces the exact path observed in the real environment: target at
    /// index 0, sibling at index 1 gets gc'd while target is fullscreen, target
    /// exits before the sibling re-registers. Without next-sibling anchors on
    /// the sibling's RecentBinding the re-registered sibling lands at the front
    /// and pushes the just-restored target one slot to the right.
    func testExitFullscreenAtIndexZeroWithSiblingGc() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer

        let target = TestWindow.new(id: 100, parent: root)
        let middleSibling = TestWindow.new(id: 200, parent: root)
        let rightSibling = TestWindow.new(id: 300, parent: root)

        // target enters fullscreen.
        let prev = MacosPrev(parent: target.parent!, index: target.ownIndex!, adaptiveWeight: 1)
        target.layoutReason = .macos(prev: prev)
        target.bind(
            to: workspace.macOsNativeFullscreenWindowsContainer,
            adaptiveWeight: WEIGHT_DOESNT_MATTER,
            index: INDEX_BIND_LAST,
        )

        // The middle sibling briefly gc's. Use the same path production code
        // takes for transient gc bookkeeping so the saved binding info is
        // identical to what the running app would see.
        let middleBinding = middleSibling.unbindFromParent()
        MacWindow.recordGcdBinding(middleSibling.windowId, middleBinding)
        MacWindow.markSeen(middleSibling.windowId)
        XCTAssertEqual(root.children.count, 1) // [rightSibling]

        // target exits fullscreen.
        try await exitMacOsNativeUnconventionalState(window: target, prev: prev, workspace: workspace)
        XCTAssertEqual(target.ownIndex, 0, "target must land at index 0 -- there is nothing in front of it")

        // The middle sibling re-registers; on restore it must use its saved
        // anchors to slot in between target and rightSibling.
        if let saved = MacWindow.popRecentlyGcdBinding(middleSibling.windowId),
           let savedParent = saved.parent
        {
            middleSibling.bind(to: savedParent, adaptiveWeight: WEIGHT_AUTO, index: saved.resolveIndex(in: savedParent))
        } else {
            XCTFail("popRecentlyGcdBinding must return saved binding")
        }

        XCTAssertEqual(target.ownIndex, 0, "target must remain at index 0 after sibling rebinds")
        XCTAssertEqual(middleSibling.ownIndex, 1)
        XCTAssertEqual(rightSibling.ownIndex, 2)
    }

    /// The hardest case: target is in the MIDDLE, the last sibling (at the
    /// right end) briefly gc's during target's fullscreen, target exits before
    /// the sibling re-registers. Naive "prevSibling anchor" would make the
    /// returning right sibling collide with target (both anchored after the
    /// leftmost window). The fix: a window whose nextSibling was nil at gc/save
    /// time must restore at the END, not after its prev sibling.
    func testExitFullscreenWhenLastSiblingGcDuringFullscreen() async throws {
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

        // While target is fullscreen, the right sibling briefly gc's. Save the
        // binding the same way production code does.
        let rightBinding = rightSibling.unbindFromParent()
        MacWindow.recordGcdBinding(rightSibling.windowId, rightBinding)
        MacWindow.markSeen(rightSibling.windowId)
        XCTAssertEqual(root.children.count, 1) // [left]

        // target exits fullscreen first.
        try await exitMacOsNativeUnconventionalState(window: target, prev: prev, workspace: workspace)
        XCTAssertEqual(target.ownIndex, 1, "target lands between left and (gone) right")

        // Then the right sibling re-registers.
        if let saved = MacWindow.popRecentlyGcdBinding(rightSibling.windowId),
           let savedParent = saved.parent
        {
            rightSibling.bind(to: savedParent, adaptiveWeight: WEIGHT_AUTO, index: saved.resolveIndex(in: savedParent))
        } else {
            XCTFail("popRecentlyGcdBinding must return saved binding")
        }

        XCTAssertEqual(left.ownIndex, 0)
        XCTAssertEqual(target.ownIndex, 1, "target must remain at index 1, not be pushed by returning right sibling")
        XCTAssertEqual(rightSibling.ownIndex, 2, "right sibling was at the end -- it must restore at the end")
    }

    /// Two adjacent siblings both come back from unconventional state in the
    /// same refresh (e.g. one fullscreened, one hidden because macOS hid the
    /// non-fullscreen app during fullscreen). Each one alone restores fine, but
    /// the order in which they rebind matters: the leftmost one must go back
    /// first, otherwise the right one anchors before the leftmost's slot.
    func testTwoExitsInSameRefreshSortedByIndex() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer

        let a = TestWindow.new(id: 100, parent: root)
        let b = TestWindow.new(id: 200, parent: root)
        let c = TestWindow.new(id: 300, parent: root)

        // Both `a` and `b` enter unconventional state. `b` first (fullscreen),
        // then `a` second (e.g., its app got hidden).
        let bPrev = MacosPrev(parent: b.parent!, index: b.ownIndex!, adaptiveWeight: 1)
        b.layoutReason = .macos(prev: bPrev)
        b.bind(to: workspace.macOsNativeFullscreenWindowsContainer, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)

        let aPrev = MacosPrev(parent: a.parent!, index: a.ownIndex!, adaptiveWeight: 1)
        a.layoutReason = .macos(prev: aPrev)
        a.bind(to: workspace.macOsNativeHiddenAppsWindowsContainer, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)

        XCTAssertEqual(root.children.count, 1) // [c]

        // Both come back in the same refresh cycle: simulate by running
        // _normalizeLayoutReason on the workspace's windows. The function must
        // sort the exits by saved index so `a` (idx 0) rebinds before `b` (idx 1).
        //
        // We replicate the sort logic directly here because invoking
        // _normalizeLayoutReason would require mocking AX state. The contract
        // we're verifying is the ordering, not the AX detection.
        let unsortedExits: [(Window, MacosPrev)] = [(b, bPrev), (a, aPrev)] // intentionally wrong order
        let sortedExits = unsortedExits.sorted { $0.1.index < $1.1.index }
        for (window, prev) in sortedExits {
            try await exitMacOsNativeUnconventionalState(window: window, prev: prev, workspace: workspace)
        }

        XCTAssertEqual(a.ownIndex, 0, "a (saved idx 0) must rebind at idx 0")
        XCTAssertEqual(b.ownIndex, 1, "b (saved idx 1) must rebind at idx 1 between a and c")
        XCTAssertEqual(c.ownIndex, 2)
    }

    /// User-reported bug: a window sits in an h_accordion together with one other
    /// window (e.g. Chrome stacked accordion-style: [home tab, YouTube]). The
    /// user presses F to fullscreen YouTube. While YouTube is in the
    /// unconventional container, the accordion has only one child left
    /// (the home tab), and `normalizeContainers` -- which runs on every refresh
    /// -- auto-flattens it. On Esc, `prev.parent` (weak) is nil and the fallback
    /// path drops YouTube as a flat sibling at the root, destroying the
    /// accordion structure the user set up.
    func testAccordionParentSurvivesFullscreenWhileChildIsAway() async throws {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let accordion = TilingContainer(parent: root, adaptiveWeight: 1, .h, .accordion, index: INDEX_BIND_LAST)
        let chromeHome = TestWindow.new(id: 1, parent: accordion)
        let youtube = TestWindow.new(id: 2, parent: accordion)
        _ = TestWindow.new(id: 3, parent: root) // neighbor at root

        // YouTube enters fullscreen.
        let prev = MacosPrev(parent: youtube.parent!, index: youtube.ownIndex!, adaptiveWeight: 1)
        youtube.layoutReason = .macos(prev: prev)
        youtube.bind(
            to: workspace.macOsNativeFullscreenWindowsContainer,
            adaptiveWeight: WEIGHT_DOESNT_MATTER,
            index: INDEX_BIND_LAST,
        )
        XCTAssertEqual(accordion.children.count, 1, "accordion has only chromeHome while YouTube is fullscreen")

        // Some unrelated refresh fires normalizeContainers. With auto-flatten on,
        // an accordion with a single child is the textbook flatten target.
        workspace.normalizeContainers()

        XCTAssertTrue(
            chromeHome.parent === accordion,
            "accordion must NOT be flattened while one of its children is in unconventional state",
        )
        XCTAssertNotNil(prev.parent, "weak ref to accordion must still resolve")

        // YouTube exits fullscreen. It must land back inside the accordion.
        try await exitMacOsNativeUnconventionalState(window: youtube, prev: prev, workspace: workspace)

        XCTAssertTrue(youtube.parent === accordion, "YouTube must restore to the accordion, not the root")
        XCTAssertEqual(accordion.children.count, 2)
        XCTAssertEqual(youtube.ownIndex, 1)
        XCTAssertEqual(chromeHome.ownIndex, 0)
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
