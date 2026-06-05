@testable import AppBundle
import XCTest

@MainActor
final class MacWindowTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testShouldFocusNextWindowOnWindowClosed() {
        XCTAssertTrue(shouldFocusNextWindowOnWindowClosed(wasFocused: true, hasOtherLiveWindowsInApp: false, appIsTerminating: false))

        config.focusNextWindowOnWindowClosed = false
        XCTAssertFalse(shouldFocusNextWindowOnWindowClosed(wasFocused: true, hasOtherLiveWindowsInApp: false, appIsTerminating: false))
        XCTAssertTrue(shouldFocusNextWindowOnWindowClosed(wasFocused: false, hasOtherLiveWindowsInApp: false, appIsTerminating: false))
        XCTAssertTrue(shouldFocusNextWindowOnWindowClosed(wasFocused: true, hasOtherLiveWindowsInApp: true, appIsTerminating: false))
        XCTAssertTrue(shouldFocusNextWindowOnWindowClosed(wasFocused: true, hasOtherLiveWindowsInApp: false, appIsTerminating: true))
    }
}
