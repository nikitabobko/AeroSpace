@testable import AppBundle
import XCTest

@MainActor
final class TrayMenuModelTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testFocusedWindowBadgesAreEmptyWithoutFocusedWindow() {
        assertEquals(menuBarFocusedWindowBadges(for: nil), [])
    }

    func testFocusedWindowBadgesForFloatingAndStickyWindow() {
        let workspace = Workspace.get(byName: "a")
        let window = TestWindow.new(id: 1, parent: workspace)
        window.isSticky = true

        assertEquals(menuBarFocusedWindowBadges(for: window), [.floating, .sticky])
    }

    func testFocusedWindowBadgesForTilingWindow() {
        let workspace = Workspace.get(byName: "a")
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        assertEquals(menuBarFocusedWindowBadges(for: window), [])
    }

    func testFocusedWindowBadgesForStickyTilingWindow() {
        let workspace = Workspace.get(byName: "a")
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        window.isSticky = true

        assertEquals(menuBarFocusedWindowBadges(for: window), [.sticky])
    }

    func testFocusedWindowBadgeSymbols() {
        assertEquals(FocusedWindowBadge.floating.systemImageName, "rectangle.fill.on.rectangle.angled.fill")
        assertEquals(FocusedWindowBadge.sticky.systemImageName, "pin.fill")
    }
}
