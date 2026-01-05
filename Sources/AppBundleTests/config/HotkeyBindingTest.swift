@testable import AppBundle
import Common
import XCTest

extension CGEventFlags: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

@MainActor
final class HotkeyBindingTest: XCTestCase {
    func testExpandCGEventFlagsVariants() {
        assertEquals(
            Set(
                CGEventFlags([.maskShift, .maskCommand])
                    .expandVariants(),
            ),
            Set([
                CGEventFlags([.maskShiftL, .maskCommandL]),
                CGEventFlags([.maskShiftL, .maskCommandR]),
                CGEventFlags([.maskShiftR, .maskCommandL]),
                CGEventFlags([.maskShiftR, .maskCommandR]),
            ]),
        )

        assertEquals(
            Set(
                CGEventFlags([.maskAlphaShift, .maskControl])
                    .expandVariants(),
            ),
            Set([
                CGEventFlags([.maskAlphaShift, .maskControlL]),
                CGEventFlags([.maskAlphaShift, .maskControlR]),
            ]),
        )
    }

    func testToString() {
        assertEquals(
            CGEventFlags([.maskShiftL, .maskControl, .maskCommandR, .maskSecondaryFn]).toString(),
            "ctrl-fn-lshift-rcmd",
        )
    }
}
