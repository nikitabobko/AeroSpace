@testable import AppBundle
import AppKit
import Common
import XCTest

// Covers `AutoRaiseController.findWindowUnderCursor`, the pure helper that
// backs `onLayoutDidChange`. The outer driver is three lines (bridge check
// + CGEvent cursor read + RaiseRouter.route); the interesting logic is in
// the helper. See autoraise-review-followups design.md §D4.
@MainActor
final class OnLayoutDidChangeTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testCursorInsideWindowReturnsIt() {
        let workspace = Workspace.get(byName: "a").apply {
            let w = TestWindow.new(id: 1, parent: $0.rootTilingContainer)
            w.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        }

        let match = AutoRaiseController.findWindowUnderCursor(
            cursor: CGPoint(x: 50, y: 50),
            workspace: workspace,
        )

        assertEquals(match?.windowId, 1)
    }

    func testCursorInDeadSpaceReturnsNil() {
        let workspace = Workspace.get(byName: "a").apply {
            let w = TestWindow.new(id: 1, parent: $0.rootTilingContainer)
            w.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        }

        let match = AutoRaiseController.findWindowUnderCursor(
            cursor: CGPoint(x: 500, y: 500),
            workspace: workspace,
        )

        assertNil(match)
    }

    // When two windows on the focused workspace both contain the cursor
    // (rects overlap — can happen with floating or misaligned layouts), the
    // helper returns the first match from `allLeafWindowsRecursive`. The
    // order is deterministic per tree-traversal semantics; pinning it here
    // so a future tree-API refactor can't silently change which window
    // wins under overlap.
    func testFirstMatchWinsForOverlappingRects() {
        let workspace = Workspace.get(byName: "a").apply {
            let w1 = TestWindow.new(id: 1, parent: $0.rootTilingContainer)
            w1.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
            let w2 = TestWindow.new(id: 2, parent: $0.rootTilingContainer)
            w2.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        }

        let match = AutoRaiseController.findWindowUnderCursor(
            cursor: CGPoint(x: 50, y: 50),
            workspace: workspace,
        )

        // First leaf in `allLeafWindowsRecursive` order. For two siblings
        // added in insertion order (w1 then w2) under the same tiling
        // container, w1 is visited first.
        assertEquals(match?.windowId, 1)
    }

    // A window whose layout has never been applied (e.g. just registered,
    // not yet refreshed) has `lastAppliedLayoutPhysicalRect = nil`. Such
    // windows must be skipped — we can't claim the cursor is over a window
    // we haven't positioned yet.
    func testWindowWithoutLastAppliedRectIsSkipped() {
        let workspace = Workspace.get(byName: "a").apply {
            // No rect set on w1.
            _ = TestWindow.new(id: 1, parent: $0.rootTilingContainer)
            let w2 = TestWindow.new(id: 2, parent: $0.rootTilingContainer)
            w2.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
        }

        let match = AutoRaiseController.findWindowUnderCursor(
            cursor: CGPoint(x: 50, y: 50),
            workspace: workspace,
        )

        assertEquals(match?.windowId, 2)
    }
}
