@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct OnWindowDetectedTest {
    init() { setUpWorkspacesForTests() }

    @Test func testMatcherCommandReceivesDetectedWindowId() async {
        let workspace = Workspace.get(byName: name)
        let focused = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let detected = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        assertEquals(focused.focusWindow(), true)
        assertEquals(globalFocus.windowOrNil?.windowId, 1)

        let callback = WindowDetectedCallback(
            matcher: .command(parseCommand("test %{window-id} = 2").cmdOrDie),
            rawRun: .empty,
        )

        assertEquals(await callback.matches(detected), true)
        assertEquals(await callback.matches(focused), false)
    }

    @Test func testRunCommandReceivesDetectedWindowIdInEnv() async {
        let workspaceA = Workspace.get(byName: "a")
        let focused = TestWindow.new(id: 1, parent: workspaceA.rootTilingContainer)
        let detected = TestWindow.new(id: 2, parent: workspaceA.rootTilingContainer)
        assertEquals(focused.focusWindow(), true)
        assertEquals(globalFocus.windowOrNil?.windowId, 1)

        config.onWindowDetected = [
            WindowDetectedCallback(
                matcher: .command(.empty), // true
                rawRun: parseCommand("move-node-to-workspace b").cmdOrDie,
            ),
        ]

        await runOnWindowDetected(ifConventional: detected) // todo: tryOnWindowDetected must not be called manually in tests

        assertEquals((Workspace.get(byName: "b").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 2)
        assertEquals((workspaceA.rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    // Finder on workspace b, a rule sends the app to workspace a, space in Finder opens Quick Look.
    // The preview must stay on b, the workspace of the Finder it was opened from.
    @Test func testQuickLookPanelStaysOnWorkspaceWhereItWasOpened() async {
        let workspaceB = Workspace.get(byName: "b")
        let finder = TestWindow.new(id: 1, parent: workspaceB.rootTilingContainer)
        assertEquals(finder.focusWindow(), true)
        let quickLook = TestWindow.new(id: 2, parent: workspaceB.floatingWindowsContainer)
        quickLook.isQuickLookPanelForTest = true

        config.onWindowDetected = [
            WindowDetectedCallback(
                matcher: .command(.empty), // true
                rawRun: parseCommand("move-node-to-workspace a").cmdOrDie,
            ),
        ]

        await runOnWindowDetected(ifConventional: quickLook)

        assertEquals(quickLook.nodeWorkspace?.name, "b")
        assertEquals(Workspace.get(byName: "a").isEffectivelyEmpty, true)
    }

    // Finder reuses one Quick Look panel (same window id) for every preview.
    // 1. Preview opened and closed on workspace a. Closing it caches the whole world (lock screen defence)
    // 2. User switches to workspace b and hits space in Finder again
    // 3. The panel reappears with the same id. It must not be treated as "window is back after screen unlock":
    //    restoring the cache would move the preview (and the user's focus) back to workspace a
    @Test func testReappearingQuickLookPanelDoesNotRestoreClosedWindowsCache() async throws {
        resetClosedWindowsCache()
        let workspaceA = Workspace.get(byName: "a")
        let workspaceB = Workspace.get(byName: "b")
        TestWindow.new(id: 1, parent: workspaceA.rootTilingContainer)
        let finderOnB = TestWindow.new(id: 3, parent: workspaceB.rootTilingContainer)
        let quickLook = TestWindow.new(id: 2, parent: workspaceA.floatingWindowsContainer)
        quickLook.isQuickLookPanelForTest = true
        assertEquals(quickLook.focusWindow(), true)

        cacheClosedWindowIfNeeded() // What garbageCollect does when the panel is closed
        quickLook.unbindFromParent()

        assertEquals(finderOnB.focusWindow(), true)
        _ = quickLook.bindAsFloatingWindow(to: workspaceB) // New windows are bound to the focused workspace

        assertEquals(try await restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: quickLook), false)
        assertEquals(quickLook.nodeWorkspace?.name, "b")
        assertEquals(globalFocus.workspace.name, "b")
    }
}
