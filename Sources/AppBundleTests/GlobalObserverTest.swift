@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct GlobalObserverTest {
    @Test func testDesktopClickOnOtherWorkspaceFocusesIt() {
        setUpWorkspacesForTests()
        let focused = Workspace.get(byName: "focused")
        let clicked = Workspace.get(byName: "clicked")
        check(focused.focusWorkspace())
        check(mainMonitorInfo.setVisibleWorkspace(clicked))

        assertEquals(workspaceToFocusAfterLeftMouseUp(
            mouseLocation: mainMonitorInfo.visibleRect.center,
            clickedMonitor: mainMonitorInfo,
            isClickOnDesktop: true,
        ), clicked)
    }

    @Test func testNonDesktopClickDoesNotFocusClickedMonitor() {
        setUpWorkspacesForTests()
        let focused = Workspace.get(byName: "focused")
        let clicked = Workspace.get(byName: "clicked")
        check(focused.focusWorkspace())
        check(mainMonitorInfo.setVisibleWorkspace(clicked))

        assertNil(workspaceToFocusAfterLeftMouseUp(
            mouseLocation: mainMonitorInfo.visibleRect.center,
            clickedMonitor: mainMonitorInfo,
            isClickOnDesktop: false,
        ))
    }

    @Test func testDesktopClickOnFocusedWorkspaceDoesNotFocus() {
        setUpWorkspacesForTests()
        let focused = Workspace.get(byName: "focused")
        check(focused.focusWorkspace())
        check(mainMonitorInfo.setVisibleWorkspace(focused))

        assertNil(workspaceToFocusAfterLeftMouseUp(
            mouseLocation: mainMonitorInfo.visibleRect.center,
            clickedMonitor: mainMonitorInfo,
            isClickOnDesktop: true,
        ))
    }

    @Test func testClickOnDesktopReturnsFalseWhenNonDesktopWindowContainsMouseLocation() {
        assertFalse(isClickOnDesktop(
            mouseLocation: Point(x: 100, y: 100),
            windowInfos: [
                windowInfo(bounds: CGRect(x: 50, y: 50, width: 100, height: 100)),
            ],
        ))
    }

    @Test func testClickOnDesktopReturnsTrueWhenNoNonDesktopWindowContainsMouseLocation() {
        assertTrue(isClickOnDesktop(
            mouseLocation: Point(x: 100, y: 100),
            windowInfos: [
                windowInfo(bounds: CGRect(x: 200, y: 200, width: 100, height: 100)),
            ],
        ))
    }

    @Test func testClickOnDesktopIgnoresTransparentWindowInfo() {
        assertTrue(isClickOnDesktop(
            mouseLocation: Point(x: 100, y: 100),
            windowInfos: [
                windowInfo(bounds: CGRect(x: 50, y: 50, width: 100, height: 100), alpha: 0),
            ],
        ))
    }
}

private func windowInfo(bounds: CGRect, alpha: Double = 1) -> NSDictionary {
    let result = NSMutableDictionary()
    result[kCGWindowBounds] = bounds.dictionaryRepresentation
    result[kCGWindowAlpha] = NSNumber(value: alpha)
    return result
}
