@testable import AppBundle
import XCTest

@MainActor
final class FocusCacheTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testStayOnWorkspaceWhenAppQuits() {
        let quitting = TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        let other = TestWindow.new(id: 2, parent: Workspace.get(byName: "b").rootTilingContainer)
        assertEquals(quitting.focusWindow(), true)
        quitting.unbindFromParent() // The dead window might be already garbage collected
        let prevApp = TestApp.shared
        config.stayOnWorkspaceWhenAppQuits = true

        // The previous app is alive: macOS focus moved for another reason (cmd-tab, click, etc.), follow it
        assertEquals(isFocusHandedOverByQuittingApp(other, prevApp: prevApp), false)

        // The previous app quit: macOS hands the focus to the app used before it, don't follow it to another workspace
        prevApp.isTerminated = true
        assertEquals(isFocusHandedOverByQuittingApp(other, prevApp: prevApp), true)
        assertEquals(isFocusHandedOverByQuittingApp(other, prevApp: nil), false)

        // Disabled by default
        config.stayOnWorkspaceWhenAppQuits = false
        assertEquals(isFocusHandedOverByQuittingApp(other, prevApp: prevApp), false)
    }
}
