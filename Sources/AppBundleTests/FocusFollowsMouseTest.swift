@testable import AppBundle
import Common
import XCTest

final class FocusFollowsMouseTest: XCTestCase {
    func testNativeFullscreenWindow() {
        let window: [String: Json] = ["AXRole": .string("AXWindow"), "AXFullScreen": .bool(true)]
        XCTAssertFalse(window.shouldFocusFollowMouse())
    }

    func testContentInsideNativeFullscreenWindow() {
        let element: [String: Json] = [
            "AXRole": .string("AXWebArea"),
            "AXWindow": .dict(["AXRole": .string("AXWindow"), "AXFullScreen": .bool(true)]),
        ]
        XCTAssertFalse(element.shouldFocusFollowMouse())
    }

    func testRegularWindowAndContent() {
        let window: [String: Json] = ["AXRole": .string("AXWindow"), "AXFullScreen": .bool(false)]
        let element: [String: Json] = ["AXRole": .string("AXButton"), "AXWindow": .dict(window)]
        XCTAssertTrue(window.shouldFocusFollowMouse())
        XCTAssertTrue(element.shouldFocusFollowMouse())
    }

    func testWindowWithoutFullscreenAttribute() {
        let window: [String: Json] = ["AXRole": .string("AXWindow")]
        XCTAssertTrue(window.shouldFocusFollowMouse())
    }

    func testMenuWithoutWindow() {
        let element: [String: Json] = ["AXRole": .string("AXMenuItem")]
        XCTAssertFalse(element.shouldFocusFollowMouse())
    }
}
