@testable import AppBundle
import Testing

@MainActor
@Suite(.serializedGlobally)
struct TrayMenuModelTest {
    init() { setUpWorkspacesForTests() }

    @Test func testFocusedWindowBadgesAreEmptyWithoutFocusedWindow() {
        assertEquals(menuBarFocusedWindowBadges(for: nil), [])
    }

    @Test func testFocusedWindowBadgesForFloatingAndStickyWindow() {
        let workspace = Workspace.get(byName: "a")
        let window = TestWindow.new(id: 1, parent: workspace.floatingWindowsContainer)
        window.isSticky = true

        assertEquals(menuBarFocusedWindowBadges(for: window), [.floating, .sticky])
    }

    @Test func testFocusedWindowBadgesForTilingWindow() {
        let workspace = Workspace.get(byName: "a")
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        assertEquals(menuBarFocusedWindowBadges(for: window), [])
    }

    @Test func testFocusedWindowBadgesForStickyTilingWindow() {
        let workspace = Workspace.get(byName: "a")
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        window.isSticky = true

        assertEquals(menuBarFocusedWindowBadges(for: window), [.sticky])
    }

    @Test func testFocusedWindowBadgeSymbols() {
        assertEquals(FocusedWindowBadge.floating.systemImageName, "rectangle.fill.on.rectangle.angled.fill")
        assertEquals(FocusedWindowBadge.sticky.systemImageName, "pin.fill")
    }
}
