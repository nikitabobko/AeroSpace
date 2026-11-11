@testable import AppBundle
import AppKit
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct WorkspaceSlideTest {
    init() { setUpWorkspacesForTests() }

    private let monitor = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800)

    @Test func testDirectionFollowsWorkspaceOrder() {
        let w1 = Workspace.get(byName: "1")
        let w2 = Workspace.get(byName: "2")
        let w10 = Workspace.get(byName: "10")
        let a = Workspace.get(byName: "a")
        assertEquals(workspaceSlideDirection(from: w1, to: w2), .towardsLeft)
        assertEquals(workspaceSlideDirection(from: w2, to: w1), .towardsRight)
        assertEquals(workspaceSlideDirection(from: w2, to: w10), .towardsLeft)
        assertEquals(workspaceSlideDirection(from: w10, to: a), .towardsLeft)
        assertEquals(workspaceSlideDirection(from: a, to: w1), .towardsRight)
    }

    @Test func testEntryIsFullyOutsideOnTheEntrySide() {
        let target = CGPoint(x: 10, y: 20)
        let towardsLeft = WorkspaceSlide(monitorRect: monitor, direction: .towardsLeft, durationMs: 250)
        assertEquals(towardsLeft.entryTopLeft(for: target), CGPoint(x: 1010, y: 20))
        let towardsRight = WorkspaceSlide(monitorRect: monitor, direction: .towardsRight, durationMs: 250)
        assertEquals(towardsRight.entryTopLeft(for: CGPoint(x: 500, y: 20)), CGPoint(x: -500, y: 20))
    }

    @Test func testExitIsFullyOutsideOnTheExitSide() {
        let towardsLeft = WorkspaceSlide(monitorRect: monitor, direction: .towardsLeft, durationMs: 250)
        let towardsRight = WorkspaceSlide(monitorRect: monitor, direction: .towardsRight, durationMs: 250)
        let frame = Rect(topLeftX: 100, topLeftY: 30, width: 400, height: 300)
        assertEquals(towardsLeft.exitTopLeft(from: frame), CGPoint(x: -900, y: 30))
        assertEquals(towardsRight.exitTopLeft(from: frame), CGPoint(x: 1100, y: 30))

        let enteringFromTheRight = Rect(topLeftX: 1200, topLeftY: 30, width: 400, height: 300)
        assertEquals(towardsLeft.exitTopLeft(from: enteringFromTheRight), CGPoint(x: -400, y: 30))
        let enteringFromTheLeft = Rect(topLeftX: -900, topLeftY: 30, width: 400, height: 300)
        assertEquals(towardsRight.exitTopLeft(from: enteringFromTheLeft), CGPoint(x: 1000, y: 30))
    }

    @Test func testSlideIsUnsafeWithHorizontalNeighbor() {
        let right = Rect(topLeftX: 1000, topLeftY: 0, width: 1920, height: 1080)
        let left = Rect(topLeftX: -1440, topLeftY: 100, width: 1440, height: 900)
        let above = Rect(topLeftX: 0, topLeftY: -900, width: 1440, height: 900)
        assertTrue(isWorkspaceSlideSafe(monitorRect: monitor, otherMonitorRects: []))
        assertTrue(isWorkspaceSlideSafe(monitorRect: monitor, otherMonitorRects: [above]))
        assertFalse(isWorkspaceSlideSafe(monitorRect: monitor, otherMonitorRects: [right]))
        assertFalse(isWorkspaceSlideSafe(monitorRect: monitor, otherMonitorRects: [left]))
    }

    @Test func testDetectSlides() {
        let w1 = Workspace.get(byName: "1")
        let w2 = Workspace.get(byName: "2")
        let key = monitor.topLeftCorner
        let slides = detectWorkspaceSlides(
            previous: [key: "1"],
            current: [key: w2],
            monitorRects: [key: monitor],
            existingWorkspaces: ["1": w1, "2": w2],
            durationMs: 250,
        )
        let expected = WorkspaceSlide(monitorRect: monitor, direction: .towardsLeft, durationMs: 250)
        assertEquals(slides.incoming, [w2: expected])
        assertEquals(slides.outgoing, [w1: expected])
    }

    @Test func testNoSlideWhenDisabledUnchangedOrFirstLayout() {
        let w1 = Workspace.get(byName: "1")
        let w2 = Workspace.get(byName: "2")
        let key = monitor.topLeftCorner
        let all = ["1": w1, "2": w2]
        let disabled = detectWorkspaceSlides(previous: [key: "1"], current: [key: w2], monitorRects: [key: monitor], existingWorkspaces: all, durationMs: 0)
        assertTrue(disabled.incoming.isEmpty && disabled.outgoing.isEmpty)
        let unchanged = detectWorkspaceSlides(previous: [key: "2"], current: [key: w2], monitorRects: [key: monitor], existingWorkspaces: all, durationMs: 250)
        assertTrue(unchanged.incoming.isEmpty && unchanged.outgoing.isEmpty)
        let first = detectWorkspaceSlides(previous: [:], current: [key: w2], monitorRects: [key: monitor], existingWorkspaces: all, durationMs: 250)
        assertTrue(first.incoming.isEmpty && first.outgoing.isEmpty)
        let gone = detectWorkspaceSlides(previous: [key: "gone"], current: [key: w2], monitorRects: [key: monitor], existingWorkspaces: all, durationMs: 250)
        assertTrue(gone.incoming.isEmpty && gone.outgoing.isEmpty)
    }

    @Test func testNoSlideWhenWorkspaceMovesBetweenMonitors() {
        let w1 = Workspace.get(byName: "1")
        let w2 = Workspace.get(byName: "2")
        let second = Rect(topLeftX: 0, topLeftY: -900, width: 1000, height: 800)
        let key1 = monitor.topLeftCorner
        let key2 = second.topLeftCorner
        let swapped = detectWorkspaceSlides(
            previous: [key1: "1", key2: "2"],
            current: [key1: w2, key2: w1],
            monitorRects: [key1: monitor, key2: second],
            existingWorkspaces: ["1": w1, "2": w2],
            durationMs: 250,
        )
        assertTrue(swapped.incoming.isEmpty && swapped.outgoing.isEmpty)
    }

    @Test func testNoSlideOnMonitorWithHorizontalNeighbor() {
        let w1 = Workspace.get(byName: "1")
        let w2 = Workspace.get(byName: "2")
        let w3 = Workspace.get(byName: "3")
        let neighbor = Rect(topLeftX: 1000, topLeftY: 0, width: 1000, height: 800)
        let key1 = monitor.topLeftCorner
        let key2 = neighbor.topLeftCorner
        let slides = detectWorkspaceSlides(
            previous: [key1: "1", key2: "3"],
            current: [key1: w2, key2: w3],
            monitorRects: [key1: monitor, key2: neighbor],
            existingWorkspaces: ["1": w1, "2": w2, "3": w3],
            durationMs: 250,
        )
        assertTrue(slides.incoming.isEmpty && slides.outgoing.isEmpty)
    }
}
