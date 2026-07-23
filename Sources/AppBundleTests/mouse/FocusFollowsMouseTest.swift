@testable import AppBundle
import Common
import XCTest

@MainActor
final class FocusFollowsMouseTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testKeepFocusWhenMouseIsWithinFocusedWindowRealFrame() async throws {
        let workspace = Workspace.get(byName: name)
        var left: Window!
        workspace.rootTilingContainer.apply {
            // The layout is 50/50, but the left window doesn't shrink below 600 (AX minimum size)
            left = TestWindow.new(id: 1, parent: $0, rect: Rect(topLeftX: 0, topLeftY: 0, width: 600, height: 1000))
            TestWindow.new(id: 2, parent: $0, rect: Rect(topLeftX: 500, topLeftY: 0, width: 500, height: 1000))
        }
        left.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 500, height: 1000)
        workspace.rootTilingContainer.children[1].lastAppliedLayoutPhysicalRect = Rect(topLeftX: 500, topLeftY: 0, width: 500, height: 1000)
        _ = left.focusWindow()

        // The mouse is inside the left window overhang. It's the right window territory according to the layout
        var window = try await CGPoint(x: 550, y: 500).windowUnderMouseToFocus(in: workspace)
        assertNil(window)

        // The mouse is past the left window real frame
        window = try await CGPoint(x: 700, y: 500).windowUnderMouseToFocus(in: workspace)
        assertEquals(window?.windowId, 2)
    }
}
