@testable import AppBundle
import Testing

struct WindowDestructionFocusTest {
    @Test func testNativeFocusWhenAnotherAppIsFocused() {
        #expect(mustNativeFocusAfterWindowDestruction(focusedAppPid: 2, deadWindowAppPid: 1))
    }

    @Test func testNativeFocusWhenNoWindowIsFocused() {
        #expect(mustNativeFocusAfterWindowDestruction(focusedAppPid: nil, deadWindowAppPid: 1))
    }

    // https://github.com/nikitabobko/AeroSpace/issues/201
    @Test func testNoNativeFocusWhenSameAppIsFocused() {
        #expect(!mustNativeFocusAfterWindowDestruction(focusedAppPid: 1, deadWindowAppPid: 1))
    }
}
