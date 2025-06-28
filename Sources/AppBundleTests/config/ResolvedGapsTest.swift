@testable import AppBundle
import Common
import XCTest

@MainActor
final class ResolvedGapsTest: XCTestCase {
    func testApplyToRectWithStandardGaps() {
        let gaps = Gaps(inner: .init(vertical: 5, horizontal: 5), outer: .init(left: 10, bottom: 10, top: 10, right: 10))
        let resolvedGaps = ResolvedGaps(gaps: gaps, monitor: mainMonitor)

        let baseRect = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 1000)
        let result = resolvedGaps.applyToRect(baseRect)

        assertEquals(result.topLeftX, 10.0)
        assertEquals(result.topLeftY, 10.0)
        assertEquals(result.width, 980.0)
        assertEquals(result.height, 980.0)
    }

    func testApplyToRectWithZeroGaps() {
        let gaps = Gaps.zero
        let resolvedGaps = ResolvedGaps(gaps: gaps, monitor: mainMonitor)

        let baseRect = Rect(topLeftX: 100, topLeftY: 100, width: 800, height: 600)
        let result = resolvedGaps.applyToRect(baseRect)

        assertEquals(result.topLeftX, 100.0)
        assertEquals(result.topLeftY, 100.0)
        assertEquals(result.width, 800.0)
        assertEquals(result.height, 600.0)
    }

    func testApplyToRectWithAsymmetricGaps() {
        let gaps = Gaps(inner: .init(vertical: 5, horizontal: 5), outer: .init(left: 20, bottom: 5, top: 30, right: 10))
        let resolvedGaps = ResolvedGaps(gaps: gaps, monitor: mainMonitor)

        let baseRect = Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080)
        let result = resolvedGaps.applyToRect(baseRect)

        assertEquals(result.topLeftX, 20.0)
        assertEquals(result.topLeftY, 30.0)
        assertEquals(result.width, 1890.0)
        assertEquals(result.height, 1045.0)
    }

    func testApplyToRectWithSingleWindowGap() {
        let gaps = Gaps(inner: .init(vertical: 5, horizontal: 5), outer: .init(left: 10, bottom: 10, top: 10, right: 10))
        let resolvedGaps = ResolvedGaps(gaps: gaps, monitor: mainMonitor, singleWindowSideGap: 100)

        let baseRect = Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080)
        let result = resolvedGaps.applyToRect(baseRect)

        assertEquals(result.topLeftX, 110.0)
        assertEquals(result.topLeftY, 10.0)
        assertEquals(result.width, 1700.0)
        assertEquals(result.height, 1060.0)
    }

    func testApplyToRectWithLargeGaps() {
        let gaps = Gaps(inner: .init(vertical: 5, horizontal: 5), outer: .init(left: 400, bottom: 300, top: 300, right: 400))
        let resolvedGaps = ResolvedGaps(gaps: gaps, monitor: mainMonitor)

        let baseRect = Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080)
        let result = resolvedGaps.applyToRect(baseRect)

        assertEquals(result.topLeftX, 400.0)
        assertEquals(result.topLeftY, 300.0)
        assertEquals(result.width, 1120.0)
        assertEquals(result.height, 480.0)
    }

    func testApplyToRectWithNegativePosition() {
        let gaps = Gaps(inner: .init(vertical: 5, horizontal: 5), outer: .init(left: 10, bottom: 10, top: 10, right: 10))
        let resolvedGaps = ResolvedGaps(gaps: gaps, monitor: mainMonitor)

        let baseRect = Rect(topLeftX: -100, topLeftY: -100, width: 1920, height: 1080)
        let result = resolvedGaps.applyToRect(baseRect)

        assertEquals(result.topLeftX, -90.0)
        assertEquals(result.topLeftY, -90.0)
        assertEquals(result.width, 1900.0)
        assertEquals(result.height, 1060.0)
    }
}
