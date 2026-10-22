@testable import AppBundle
import Common
import XCTest

final class AccordionPaddingsTest: XCTestCase {
    private func paddings(_ count: Int, mru: Int, _ padding: CGFloat, _ style: AccordionStyle) -> [[CGFloat]] {
        accordionPaddings(count: count, mruIndex: mru, padding: padding, style: style).map { [$0.0, $0.1] }
    }

    func testClassic() {
        assertEquals(paddings(1, mru: 0, 30, .classic), [[0, 0]])
        assertEquals(paddings(4, mru: 1, 30, .classic), [[0, 30], [30, 30], [60, 0], [30, 0]])
    }

    func testFanSingleWindow() {
        assertEquals(paddings(1, mru: 0, 120, .fan), [[0, 0]])
    }

    func testFanStripsHalveWithDistance() {
        assertEquals(paddings(5, mru: 2, 120, .fan), [
            [0, 180], // strip 0..60
            [60, 180], // strip 60..180
            [180, 180], // focused
            [180, 60],
            [180, 0],
        ])
    }

    func testFanMinStrip() {
        // Trailing strips: 120, 60, 30, 15, 7.5, 6, 6
        let result = paddings(8, mru: 0, 120, .fan)
        assertEquals(result[0], [0, 244.5])
        assertEquals(result[1], [0, 124.5])
        assertEquals(result[6], [0, 6])
        assertEquals(result[7], [0, 0])
    }

    func testFanZeroPadding() {
        assertEquals(paddings(3, mru: 1, 0, .fan), [[0, 0], [0, 0], [0, 0]])
    }
}
