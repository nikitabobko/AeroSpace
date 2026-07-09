@testable import AppBundle
import XCTest

final class FocusCacheTest: XCTestCase {
    private let now = ContinuousClock().now

    func testCloseProtectionSuppressesCrossWorkspaceFocus() {
        var protection = NativeFocusRaceProtection()
        protection.recordWindowClose(workspaceName: "a", now: now)

        XCTAssertTrue(protection.shouldSuppressAfterClose(
            currentWorkspaceName: "a",
            nativeWorkspaceName: "b",
            now: now,
        ))
    }

    func testCloseProtectionOnlySuppressesFocusLeavingTheClosedWorkspace() {
        var protection = NativeFocusRaceProtection()
        protection.recordWindowClose(workspaceName: "a", now: now)

        XCTAssertFalse(protection.shouldSuppressAfterClose(
            currentWorkspaceName: "a",
            nativeWorkspaceName: "a",
            now: now,
        ))
        XCTAssertFalse(protection.shouldSuppressAfterClose(
            currentWorkspaceName: "b",
            nativeWorkspaceName: "c",
            now: now,
        ))
    }

    func testCloseProtectionExpires() {
        var protection = NativeFocusRaceProtection()
        protection.recordWindowClose(workspaceName: "a", now: now)

        XCTAssertFalse(protection.shouldSuppressAfterClose(
            currentWorkspaceName: "a",
            nativeWorkspaceName: "b",
            now: now.advanced(by: NativeFocusRaceProtection.closeProtectionDuration),
        ))
    }

    func testAppActivationDelaysCrossWorkspaceFocus() {
        var protection = NativeFocusRaceProtection()
        protection.recordAppActivation(appPid: 42, now: now)

        XCTAssertEqual(
            protection.appActivationDelay(
                appPid: 42,
                currentWorkspaceName: "a",
                nativeWorkspaceName: "b",
                now: now,
            ),
            NativeFocusRaceProtection.appActivationGraceDuration,
        )
        XCTAssertNil(protection.appActivationDelay(
            appPid: 42,
            currentWorkspaceName: "a",
            nativeWorkspaceName: "a",
            now: now,
        ))
        XCTAssertNil(protection.appActivationDelay(
            appPid: 7,
            currentWorkspaceName: "a",
            nativeWorkspaceName: "b",
            now: now,
        ))
    }

    func testSameWorkspaceFocusClearsActivationDelay() {
        var protection = NativeFocusRaceProtection()
        protection.recordAppActivation(appPid: 42, now: now)
        protection.clearAppActivation(appPid: 42)

        XCTAssertNil(protection.appActivationDelay(
            appPid: 42,
            currentWorkspaceName: "a",
            nativeWorkspaceName: "b",
            now: now,
        ))
    }
}
