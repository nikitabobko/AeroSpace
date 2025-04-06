import AppKit
import Common

@MainActor
var appForTests: (any AbstractApp)? = nil

@MainActor
private var focusedApp: (any AbstractApp)? {
    get async throws {
        if isUnitTest {
            return appForTests
        } else {
            check(appForTests == nil)
            return try await NSWorkspace.shared.frontmostApplication.flatMapAsyncMainActor(MacApp.getOrRegister)
        }
    }
}

@MainActor
func getNativeFocusedWindow() async throws -> Window? {
    try await focusedApp?.getFocusedWindow()
}
