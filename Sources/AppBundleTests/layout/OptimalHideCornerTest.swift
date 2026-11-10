@testable import AppBundle
import Common
import XCTest

@MainActor
final class OptimalHideCornerTest: XCTestCase {
    private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Rect {
        Rect(topLeftX: x, topLeftY: y, width: w, height: h)
    }

    func testSingleMonitorKeepsBottomRight() {
        let main = rect(0, 0, 1000, 1000)
        assertEquals(optimalHideCorner(monitorRect: main, allMonitorRects: [main]), .bottomRightCorner)
    }

    // The flicker case: a display sits beyond the bottom-RIGHT corner and below it, so a window
    // parked there has its body over that display. The left body direction cannot reach it.
    func testDisplayBelowRightFlipsToBottomLeft() {
        let main = rect(0, 0, 1000, 1000)
        let lowerRight = rect(1200, 1100, 500, 500)
        assertEquals(optimalHideCorner(monitorRect: main, allMonitorRects: [main, lowerRight]), .bottomLeftCorner)
    }

    // Mirror case: a display below-LEFT of the corner (his left screen sits 29 pts lower), so the
    // bottom-right corner is the safe one — this is the arrangement measured on the real machine.
    func testDisplayBelowLeftKeepsBottomRight() {
        let main = rect(0, 0, 1000, 1000)
        let lowerLeft = rect(-1200, 1100, 500, 500)
        assertEquals(optimalHideCorner(monitorRect: main, allMonitorRects: [main, lowerLeft]), .bottomRightCorner)
    }

    // A display to the right but entirely ABOVE the corner cannot be reached by a body that runs
    // downward, so the default must not change.
    func testDisplayRightButAboveDoesNotFlip() {
        let main = rect(0, 0, 1000, 1000)
        let rightAbove = rect(1200, 0, 500, 500)
        assertEquals(optimalHideCorner(monitorRect: main, allMonitorRects: [main, rightAbove]), .bottomRightCorner)
    }

    // No safe corner exists: both directions reach another display. Documented behaviour is to
    // keep bottom-right rather than oscillate between two equally bad choices.
    func testBothCornersSpillKeepsBottomRight() {
        let main = rect(0, 0, 1000, 1000)
        let belowLeft = rect(-1200, 1100, 500, 500)
        let belowRight = rect(1200, 1100, 500, 500)
        assertEquals(optimalHideCorner(monitorRect: main, allMonitorRects: [main, belowLeft, belowRight]), .bottomRightCorner)
    }
}
