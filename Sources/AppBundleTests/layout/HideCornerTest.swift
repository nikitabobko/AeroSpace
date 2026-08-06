@testable import AppBundle
import XCTest

final class HideCornerTest: XCTestCase {
    private let center = Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080)

    func testPrefersExistingLocalCornerWhenItIsFree() {
        let right = Rect(topLeftX: 1920, topLeftY: 300, width: 1080, height: 1920)
        XCTAssertEqual(
            optimalHideCorner(for: center, among: [center, right]),
            .bottomLeftCorner,
        )
    }

    func testFallsBackToGlobalEdgeWhenBothLocalCornersAreBlocked() {
        let left = Rect(topLeftX: -1080, topLeftY: 343, width: 1080, height: 1920)
        let right = Rect(topLeftX: 1920, topLeftY: 299, width: 1080, height: 1920)
        let builtIn = Rect(topLeftX: 102, topLeftY: 1080, width: 1512, height: 982)
        XCTAssertEqual(
            optimalHideCorner(for: center, among: [center, left, right, builtIn]),
            .globalBottomRightCorner,
        )
    }

    func testPreservesBottomRightTieBreakForSingleMonitor() {
        XCTAssertEqual(
            optimalHideCorner(for: center, among: [center]),
            .bottomRightCorner,
        )
    }
}
