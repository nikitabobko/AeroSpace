@testable import AppBundle
import XCTest

@MainActor
final class FocusAfterWindowRemovalTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
    }

    func testPrefersPreviousWindowOnSameWorkspace() {
        let workspace = Workspace.get(byName: "a")
        let previous = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let fallback = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        fallback.markAsMostRecentChild()

        let resolved = resolveFocusAfterWindowRemoval(wasFocused: true, previousWindow: previous, workspace: workspace)

        assertEquals(resolved.windowOrNil, previous)
        assertEquals(resolved.workspace, workspace)
    }

    func testFallsBackWhenPreviousWindowBelongsToAnotherWorkspace() {
        let workspace = Workspace.get(byName: "a")
        let fallback = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let previous = TestWindow.new(id: 2, parent: Workspace.get(byName: "b").rootTilingContainer)

        let resolved = resolveFocusAfterWindowRemoval(wasFocused: true, previousWindow: previous, workspace: workspace)

        assertEquals(resolved.windowOrNil, fallback)
    }

    func testFallsBackWhenPreviousWindowNoLongerExists() {
        let workspace = Workspace.get(byName: "a")
        let fallback = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        let resolved = resolveFocusAfterWindowRemoval(wasFocused: true, previousWindow: nil, workspace: workspace)

        assertEquals(resolved.windowOrNil, fallback)
    }

    func testFallsBackWhenRemovedWindowWasNotFocused() {
        let workspace = Workspace.get(byName: "a")
        let previous = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let fallback = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        fallback.markAsMostRecentChild()

        let resolved = resolveFocusAfterWindowRemoval(wasFocused: false, previousWindow: previous, workspace: workspace)

        assertEquals(resolved.windowOrNil, fallback)
    }

    func testPreviousFocusedWindowSurvivesCurrentWindowRemoval() async {
        let workspace = Workspace.get(byName: "a")
        let previous = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let removed = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)

        _ = previous.focusWindow()
        await checkOnFocusChangedCallbacks_nonCancellable()
        _ = removed.focusWindow()
        await checkOnFocusChangedCallbacks_nonCancellable()
        removed.unbindFromParent()

        assertEquals(previousFocusedWindowOrNil, previous)
    }
}
