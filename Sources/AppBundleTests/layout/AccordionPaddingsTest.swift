@testable import AppBundle
import Common
import XCTest

final class AccordionPaddingsTest: XCTestCase {
    private func paddings(_ count: Int, mru: Int, _ padding: CGFloat) -> [[CGFloat]] {
        accordionPaddings(count: count, mruIndex: mru, padding: padding).map { [$0.0, $0.1] }
    }

    func testPaddings() {
        assertEquals(paddings(1, mru: 0, 30), [[0, 0]])
        assertEquals(paddings(4, mru: 1, 30), [[0, 30], [30, 30], [60, 0], [30, 0]])
    }
}
