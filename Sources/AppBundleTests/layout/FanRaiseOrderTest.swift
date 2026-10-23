@testable import AppBundle
import Common
import XCTest

final class FanRaiseOrderTest: XCTestCase {
    /// Window ids are child indices. 'stack' lists the on-screen windows from the front to the back
    private func raiseOrder(_ count: Int, mru: Int, stack: [UInt32]) -> [UInt32] {
        fanRaiseOrder(
            children: (0 ..< count).map { [UInt32($0)] },
            mruIndex: mru,
            stackingOrder: Dictionary(uniqueKeysWithValues: stack.enumerated().map { ($1, $0) }),
        )
    }

    func testAlreadyStacked() {
        assertEquals(raiseOrder(5, mru: 2, stack: [2, 1, 3, 0, 4]), [])
    }

    func testFocusNeighbor() {
        assertEquals(raiseOrder(5, mru: 3, stack: [2, 1, 3, 0, 4]), [3])
    }

    func testJumpRaisesWindowsInBetweenFarthestFirst() {
        // Wrap-around from the first window to the last one
        assertEquals(raiseOrder(5, mru: 4, stack: [0, 1, 2, 3, 4]), [1, 2, 3, 4])
    }

    func testOffScreenWindowsAreIgnored() {
        assertEquals(raiseOrder(5, mru: 2, stack: [2, 3, 4]), [])
    }

    func testChildWithSeveralWindowsKeepsItsOrder() {
        let result = fanRaiseOrder(
            children: [[0], [10, 11], [2]],
            mruIndex: 2,
            stackingOrder: [0: 0, 11: 1, 2: 2, 10: 3],
        )
        assertEquals(result, [10, 11, 2])
    }
}
