import AppKit
import Common

var appForTests: AbstractApp? = nil

private var focusedApp: AbstractApp? {
    if isUnitTest {
        return appForTests
    } else {
        check(appForTests == nil)
        return NSWorkspace.shared.frontmostApplication?.macApp
    }
}

func getNativeFocusedWindow(startup: Bool) -> Window? {
    focusedApp?.getFocusedWindow(startup: startup)
}
