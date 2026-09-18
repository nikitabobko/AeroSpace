@testable import AppBundle
import Common
import XCTest

@MainActor
final class AutoTilingTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        config.enableAutoTiling = true
        config.enableNormalizationFlattenContainers = true
        config.enableNormalizationOppositeOrientationForNestedContainers = true
    }

    @discardableResult
    private func openWindow(_ id: UInt32, on workspace: Workspace) -> TestWindow {
        let data = workspace.prepareTilingWindowInsertion(autoTile: true)
        let window = TestWindow.new(id: id, parent: data.parent, adaptiveWeight: data.adaptiveWeight)
        window.bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
        workspace.normalizeContainers()
        return window
    }

    func testFirstTwoWindowsUseRootOrientation() {
        let workspace = Workspace.get(byName: name)
        openWindow(1, on: workspace)
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([.window(1)]))
        openWindow(2, on: workspace)
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([.window(1), .window(2)]))
    }

    func testThirdWindowStacksAndFurtherSplitsAlternate() {
        let workspace = Workspace.get(byName: name)
        for id: UInt32 in 1 ... 3 { openWindow(id, on: workspace) }
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([
            .window(1), .v_tiles([.window(2), .window(3)]),
        ]))
        openWindow(4, on: workspace)
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([
            .window(1), .v_tiles([.window(2), .h_tiles([.window(3), .window(4)])]),
        ]))
    }

    func testSplitsMostRecentlyFocusedTileAndPreservesWeights() {
        let workspace = Workspace.get(byName: name)
        let first = openWindow(1, on: workspace)
        let second = openWindow(2, on: workspace)
        first.setWeight(.h, 700)
        second.setWeight(.h, 300)
        assertTrue(first.focusWindow())
        let third = openWindow(3, on: workspace)
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([
            .v_tiles([.window(1), .window(3)]), .window(2),
        ]))
        assertEquals(first.parent?.getWeight(.h), 700)
        assertEquals(second.getWeight(.h), 300)
        assertEquals(first.getWeight(.v), third.getWeight(.v))
    }

    func testVerticalRootSplitsHorizontally() {
        config.defaultRootContainerOrientation = .vertical
        let workspace = Workspace.get(byName: name)
        for id: UInt32 in 1 ... 3 { openWindow(id, on: workspace) }
        assertEquals(workspace.rootTilingContainer.layoutDescription, .v_tiles([
            .window(1), .h_tiles([.window(2), .window(3)]),
        ]))
    }

    func testDisabledPreservesSiblingInsertion() {
        config.enableAutoTiling = false
        let workspace = Workspace.get(byName: name)
        for id: UInt32 in 1 ... 3 { openWindow(id, on: workspace) }
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([
            .window(1), .window(2), .window(3),
        ]))
    }

    func testAccordionKeepsSiblingInsertion() {
        config.defaultRootContainerLayout = .accordion
        let workspace = Workspace.get(byName: name)
        for id: UInt32 in 1 ... 3 { openWindow(id, on: workspace) }
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_accordion([
            .window(1), .window(2), .window(3),
        ]))
    }

    func testFloatingFocusKeepsRootInsertion() {
        let workspace = Workspace.get(byName: name)
        openWindow(1, on: workspace)
        openWindow(2, on: workspace)
        let floating = TestWindow.new(id: 3, parent: workspace.floatingWindowsContainer)
        assertTrue(floating.focusWindow())
        openWindow(4, on: workspace)
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([
            .window(1), .window(2), .window(4),
        ]))
        assertTrue(floating.isFloating)
    }

    func testRetilingExistingWindowDoesNotSplit() async throws {
        let workspace = Workspace.get(byName: name)
        openWindow(1, on: workspace)
        openWindow(2, on: workspace)
        let floating = TestWindow.new(id: 3, parent: workspace.floatingWindowsContainer)
        try await floating.relayoutWindow(on: workspace, .nonCancellable, forceTile: true)
        workspace.normalizeContainers()
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([
            .window(1), .window(2), .window(3),
        ]))
    }

    func testClosingSplitWindowRestoresOriginalTile() {
        let workspace = Workspace.get(byName: name)
        openWindow(1, on: workspace)
        openWindow(2, on: workspace)
        let third = openWindow(3, on: workspace)
        third.closeAxWindow()
        workspace.normalizeContainers()
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([.window(1), .window(2)]))
        openWindow(4, on: workspace)
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([
            .window(1), .v_tiles([.window(2), .window(4)]),
        ]))
    }

    func testFloatingRuleRemovesTemporarySplit() async {
        let workspace = Workspace.get(byName: name)
        openWindow(1, on: workspace)
        openWindow(2, on: workspace)
        config.onWindowDetected = [WindowDetectedCallback(
            matcher: .command(.empty),
            rawRun: parseCommand("layout floating").cmdOrDie,
        )]
        let third = openWindow(3, on: workspace)
        await tryOnWindowDetected(third)
        workspace.normalizeContainers()
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([.window(1), .window(2)]))
        assertTrue(third.isFloating)
    }
}
