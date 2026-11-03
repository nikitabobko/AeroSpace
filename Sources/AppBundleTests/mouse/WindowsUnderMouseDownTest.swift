@testable import AppBundle
import Common
import Foundation
import XCTest

@MainActor
final class WindowsUnderMouseDownTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testOnlyWindowsOfGivenWorkspacesUnderTheLocationMatch() {
        let visible = Workspace.get(byName: "visible")
        let hidden = Workspace.get(byName: "hidden")
        visible.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0).lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)
            TestWindow.new(id: 2, parent: $0).lastAppliedLayoutPhysicalRect = Rect(topLeftX: 100, topLeftY: 0, width: 100, height: 100)
            TestWindow.new(id: 3, parent: $0) // Never laid out
        }
        // Laid out at the same place before its workspace was hidden
        TestWindow.new(id: 4, parent: hidden.rootTilingContainer).lastAppliedLayoutPhysicalRect =
            Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100)

        assertEquals(windowIdsUnder(CGPoint(x: 50, y: 50), in: [visible]), [1])
        // The resize edge between two windows belongs to both
        assertEquals(windowIdsUnder(CGPoint(x: 100, y: 50), in: [visible]), [1, 2])
        // Slightly outside the frame is still the resize edge
        assertEquals(windowIdsUnder(CGPoint(x: 205, y: 50), in: [visible]), [2])
        assertEquals(windowIdsUnder(CGPoint(x: 250, y: 50), in: [visible]), [])
    }
}
