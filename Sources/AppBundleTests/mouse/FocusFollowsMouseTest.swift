@testable import AppBundle
import XCTest

@MainActor
final class FocusFollowsMouseTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testResolvesTheExactManagedWindowUnderMouse() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        assertEquals(try await managedWindowUnderMouse(windowId: 1, location: .zero, workspace: workspace), window)
    }

    func testPrefersAHiddenFloatingWindowOverAManagedTilingWindow() async throws {
        let workspace = Workspace.get(byName: name)
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let floating = TestWindow.new(
            id: 2,
            parent: workspace.floatingWindowsContainer,
            rect: Rect(topLeftX: 10, topLeftY: 10, width: 100, height: 100),
        )

        assertEquals(
            try await managedWindowUnderMouse(windowId: 1, location: CGPoint(x: 20, y: 20), workspace: workspace),
            floating,
        )
    }

    func testKeepsTheExactFloatingWindowWhenFloatingWindowsOverlap() async throws {
        let workspace = Workspace.get(byName: name)
        let exact = TestWindow.new(
            id: 1,
            parent: workspace.floatingWindowsContainer,
            rect: Rect(topLeftX: 10, topLeftY: 10, width: 100, height: 100),
        )
        TestWindow.new(
            id: 2,
            parent: workspace.floatingWindowsContainer,
            rect: Rect(topLeftX: 10, topLeftY: 10, width: 100, height: 100),
        )

        assertEquals(
            try await managedWindowUnderMouse(windowId: 1, location: CGPoint(x: 20, y: 20), workspace: workspace),
            exact,
        )
    }

    func testDoesNotPreferFloatingWindowOverFullscreenWindow() async throws {
        let workspace = Workspace.get(byName: name)
        let fullscreen = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        fullscreen.isFullscreen = true
        TestWindow.new(
            id: 2,
            parent: workspace.floatingWindowsContainer,
            rect: Rect(topLeftX: 10, topLeftY: 10, width: 100, height: 100),
        )

        assertEquals(
            try await managedWindowUnderMouse(windowId: 1, location: CGPoint(x: 20, y: 20), workspace: workspace),
            fullscreen,
        )
    }

    func testDoesNotFallThroughAnUnmanagedOverlay() async throws {
        let workspace = Workspace.get(byName: name)
        TestWindow.new(
            id: 1,
            parent: workspace.floatingWindowsContainer,
            rect: Rect(topLeftX: 10, topLeftY: 10, width: 100, height: 100),
        )

        assertNil(try await managedWindowUnderMouse(
            windowId: 2,
            location: CGPoint(x: 20, y: 20),
            workspace: workspace,
        ))
    }

    func testDoesNotFocusAWindowFromAnotherWorkspace() async throws {
        let workspace = Workspace.get(byName: name)
        TestWindow.new(id: 1, parent: Workspace.get(byName: "other").rootTilingContainer)

        assertNil(try await managedWindowUnderMouse(windowId: 1, location: .zero, workspace: workspace))
    }
}
