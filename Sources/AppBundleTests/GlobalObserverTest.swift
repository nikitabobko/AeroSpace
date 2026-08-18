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

        assertNil(workspaceToFocusAfterLeftMouseUp(
            mouseLocation: CGPoint(x: 100, y: 10),
            clickedMonitor: monitor,
            isClickOnDesktop: true,
        ))
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

        assertEquals(workspaceToFocusAfterLeftMouseUp(
            mouseLocation: CGPoint(x: 100, y: 100),
            clickedMonitor: monitor,
            isClickOnDesktop: true,
        ), clicked)
    }

    @MainActor
    func testLeftMouseUpOnNonDesktopWindowDoesNotFocusClickedMonitor() {
        setUpWorkspacesForTests()
        let focused = Workspace.get(byName: "focused")
        let clicked = Workspace.get(byName: "clicked")
        let monitor = TestMonitor(
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 31, width: 1000, height: 769),
        )
        check(focused.focusWorkspace())
        check(monitor.setActiveWorkspace(clicked))

        assertNil(workspaceToFocusAfterLeftMouseUp(
            mouseLocation: CGPoint(x: 100, y: 100),
            clickedMonitor: monitor,
            isClickOnDesktop: false,
        ))
    }

    func testClickOnDesktopReturnsFalseWhenNonDesktopWindowContainsMouseLocation() {
        assertFalse(isClickOnDesktop(
            mouseLocation: CGPoint(x: 100, y: 100),
            windowInfos: [
                windowInfo(bounds: CGRect(x: 50, y: 50, width: 100, height: 100)),
            ],
        ))
    }

    func testClickOnDesktopReturnsTrueWhenNoNonDesktopWindowContainsMouseLocation() {
        assertTrue(isClickOnDesktop(
            mouseLocation: CGPoint(x: 100, y: 100),
            windowInfos: [
                windowInfo(bounds: CGRect(x: 200, y: 200, width: 100, height: 100)),
            ],
        ))
    }

    func testClickOnDesktopIgnoresTransparentWindowInfo() {
        assertTrue(isClickOnDesktop(
            mouseLocation: CGPoint(x: 100, y: 100),
            windowInfos: [
                windowInfo(bounds: CGRect(x: 50, y: 50, width: 100, height: 100), alpha: 0),
            ],
        ))
    }
}

private struct TestMonitor: MonitorInfo {
    let monitorAppKitNsScreenScreensId = 1
    let name = "Test Monitor"
    let rect: Rect
    let visibleRect: Rect
    let isMain = true
    var width: CGFloat { rect.width }
    var height: CGFloat { rect.height }
}

private func windowInfo(bounds: CGRect, alpha: Double = 1) -> NSDictionary {
    let result = NSMutableDictionary()
    result[kCGWindowBounds] = bounds.dictionaryRepresentation
    result[kCGWindowAlpha] = NSNumber(value: alpha)
    return result
}
