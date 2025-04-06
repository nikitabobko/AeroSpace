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
            if let frontmostApplication = NSWorkspace.shared.frontmostApplication {
                return try await MacApp.getOrRegister(frontmostApplication)
            } else {
                return nil
            }
        }
    }
}

@MainActor
func getNativeFocusedWindow() async throws -> Window? {
    try await focusedApp?.getFocusedWindow()
}
