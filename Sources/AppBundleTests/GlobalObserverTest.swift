@testable import AppBundle
import Common
import XCTest

final class GlobalObserverTest: XCTestCase {
    @MainActor
    func testLeftMouseUpOnMenuBarDoesNotFocusClickedMonitor() {
        setUpWorkspacesForTests()
        let focused = Workspace.get(byName: "focused")
        let clicked = Workspace.get(byName: "clicked")
        let monitor = TestMonitor(
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 31, width: 1000, height: 769),
        )
        check(focused.focusWorkspace())
        check(monitor.setActiveWorkspace(clicked))

        assertNil(workspaceToFocusAfterLeftMouseUp(mouseLocation: CGPoint(x: 100, y: 10), clickedMonitor: monitor))
    }

    @MainActor
    func testLeftMouseUpOnVisibleAreaFocusesClickedMonitor() {
        setUpWorkspacesForTests()
        let focused = Workspace.get(byName: "focused")
        let clicked = Workspace.get(byName: "clicked")
        let monitor = TestMonitor(
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 31, width: 1000, height: 769),
        )
        check(focused.focusWorkspace())
        check(monitor.setActiveWorkspace(clicked))

        assertEquals(workspaceToFocusAfterLeftMouseUp(mouseLocation: CGPoint(x: 100, y: 100), clickedMonitor: monitor), clicked)
    }
}

private struct TestMonitor: Monitor {
    let monitorAppKitNsScreenScreensId = 1
    let name = "Test Monitor"
    let rect: Rect
    let visibleRect: Rect
    let isMain = true
    var width: CGFloat { rect.width }
    var height: CGFloat { rect.height }
}
