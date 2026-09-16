import XCTest
@testable import AppBundle

final class AxAppCircuitBreakerTest: XCTestCase {
    func testCircuitBreakerIsScopedToPidAndExpires() {
        var state = AxAppCircuitBreakerState()
        let now = ContinuousClock().now

        state.recordTimeout(for: 42, now: now)

        XCTAssertTrue(state.shouldSkipRequests(for: 42, now: now))
        XCTAssertFalse(state.shouldSkipRequests(for: 24, now: now))
        XCTAssertFalse(state.shouldSkipRequests(for: 42, now: now.advanced(by: AxAppCircuitBreakerState.cooldownDuration)))
    }

    func testRepeatedTimeoutExtendsCooldown() {
        var state = AxAppCircuitBreakerState()
        let now = ContinuousClock().now
        let later = now.advanced(by: .milliseconds(500))

        state.recordTimeout(for: 42, now: now)
        state.recordTimeout(for: 42, now: later)

        XCTAssertTrue(state.shouldSkipRequests(for: 42, now: now.advanced(by: .seconds(1))))
        XCTAssertFalse(state.shouldSkipRequests(for: 42, now: later.advanced(by: AxAppCircuitBreakerState.cooldownDuration)))
    }
}
