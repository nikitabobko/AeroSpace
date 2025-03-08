import AppKit
import Common

@MainActor
var appForTests: (any AbstractApp)? = nil

@MainActor
private var focusedApp: (any AbstractApp)? {
    if isUnitTest {
        return appForTests
    } else {
        check(appForTests == nil)
        return NSWorkspace.shared.frontmostApplication?.macApp
    }
}

@MainActor
func getNativeFocusedWindow(startup: Bool) -> Window? {
    focusedApp?.getFocusedWindow(startup: startup)
}
