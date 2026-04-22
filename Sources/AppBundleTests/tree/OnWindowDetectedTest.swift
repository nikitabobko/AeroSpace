@testable import AppBundle
import Common
import XCTest

@MainActor
final class OnWindowDetectedTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testMatcherCommandReceivesDetectedWindowId() async throws {
        let workspace = Workspace.get(byName: name)
        let focused = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let detected = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        assertEquals(focused.focusWindow(), true)
        assertEquals(focus.windowOrNil?.windowId, 1)

        let callback = WindowDetectedCallback(
            matcher: .command(parseCommand("test %{window-id} .= 2").cmdOrDie),
            rawRun: [],
        )

        assertEquals(try await callback.matches(detected), true)
        assertEquals(try await callback.matches(focused), false)
    }
}
