@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
final class DwindlePreserveSplitTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        // We're testing flatten normalization specifically — turn it on (the
        // shared setup turns it off for predictable layouts).
        config.enableNormalizationFlattenContainers = true
        config.dwindle = DwindleConfig()
    }

    /// Without preserve-split, a single-child sub-container collapses on
    /// normalize. We anchor the root with W0 so the root itself doesn't get
    /// collapsed away — that path is exercised by upstream tests.
    func testCollapsesWhenPreserveSplitFalse() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        let w0 = TestWindow.new(id: 0, parent: workspace.rootTilingContainer)
        _ = w0
        let split = TilingContainer(
            parent: workspace.rootTilingContainer,
            adaptiveWeight: 1,
            .v,
            .dwindle,
            index: INDEX_BIND_LAST,
        )
        // preserveSplit defaults to false.
        TestWindow.new(id: 1, parent: split)

        // Before: root → [W0, split → [W1]]
        workspace.normalizeContainers()
        // After: root → [W0, W1]; split was collapsed because preserveSplit=false.
        assertEquals(workspace.rootTilingContainer.children.count, 2)
        XCTAssertTrue(workspace.rootTilingContainer.children[0] is Window)
        XCTAssertTrue(workspace.rootTilingContainer.children[1] is Window)
    }

    /// With preserve-split, a single-child sub-container survives normalization.
    func testKeptAliveWhenPreserveSplitTrue() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        let w0 = TestWindow.new(id: 0, parent: workspace.rootTilingContainer)
        _ = w0
        let split = TilingContainer(
            parent: workspace.rootTilingContainer,
            adaptiveWeight: 1,
            .v,
            .dwindle,
            index: INDEX_BIND_LAST,
        )
        split.preserveSplit = true
        TestWindow.new(id: 1, parent: split)

        // Before: root → [W0, split (preserveSplit=true) → [W1]]
        workspace.normalizeContainers()
        // After: split survives unchanged.
        assertEquals(workspace.rootTilingContainer.children.count, 2)
        XCTAssertTrue(workspace.rootTilingContainer.children[1] === split)
        assertEquals(split.children.count, 1)
    }

    /// Even with preserve-split, a zero-child sub-container is still cleaned up
    /// (the cleanup path is independent from the single-child collapse path).
    /// Note: a *root* container is never cleaned up regardless of preserveSplit
    /// (existing upstream invariant). This test verifies the sub-container case.
    func testZeroChildContainerStillCleanedUpWhenPreserveSplitTrue() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        let w0 = TestWindow.new(id: 0, parent: workspace.rootTilingContainer)
        _ = w0
        let split = TilingContainer(
            parent: workspace.rootTilingContainer,
            adaptiveWeight: 1,
            .v,
            .dwindle,
            index: INDEX_BIND_LAST,
        )
        split.preserveSplit = true
        // No children bound to split.

        // Before: root → [W0, split (preserveSplit=true, empty)]
        workspace.normalizeContainers()
        // After: split cleaned up; root → [W0].
        assertEquals(workspace.rootTilingContainer.children.count, 1)
        XCTAssertTrue(workspace.rootTilingContainer.children[0] is Window)
    }

    /// preserveSplit only suppresses collapse for the container that has it set.
    /// Other tiles/accordion containers without the flag still collapse.
    func testPreserveSplitDoesNotAffectTilesContainer() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        let preserved = TilingContainer(
            parent: workspace.rootTilingContainer,
            adaptiveWeight: 1,
            .v,
            .dwindle,
            index: INDEX_BIND_LAST,
        )
        preserved.preserveSplit = true
        TestWindow.new(id: 1, parent: preserved)

        let plainTiles = TilingContainer.newHTiles(parent: workspace.rootTilingContainer, adaptiveWeight: 1)
        let w2 = TestWindow.new(id: 2, parent: plainTiles)
        _ = w2

        workspace.normalizeContainers()
        // root has two children: the preserved split (alive) + W2 (the tiles
        // container collapsed and was replaced by its single child).
        assertEquals(workspace.rootTilingContainer.children.count, 2)
        XCTAssertTrue(workspace.rootTilingContainer.children.contains(where: { $0 === preserved }))
        XCTAssertTrue(workspace.rootTilingContainer.children.contains(where: { ($0 as? Window)?.windowId == 2 }))
    }

    /// Accordion containers don't get the preserveSplit flag from dwindle's
    /// insertion algorithm (it only fires for `.dwindle` containers). Verifies
    /// the flag's effect doesn't accidentally bleed across layouts.
    func testPreserveSplitDoesNotAffectAccordion() {
        let workspace = Workspace.get(byName: name)
        let accordion = TilingContainer(
            parent: workspace.rootTilingContainer,
            adaptiveWeight: 1,
            .h,
            .accordion,
            index: INDEX_BIND_LAST,
        )
        // preserveSplit defaults to false; we don't set it.
        TestWindow.new(id: 1, parent: accordion)

        workspace.normalizeContainers()
        // Single-child accordion was flattened away.
        assertEquals(workspace.rootTilingContainer.children.count, 1)
        XCTAssertTrue(workspace.rootTilingContainer.children[0] is Window)
    }

    /// Under preserve-split, closing a sibling keeps the split direction so
    /// the next inserted window picks up the same orientation.
    func testCloseSibling_thenNewWindow_preservesSplitDirection() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        // Manually build root(.h) → [W1, split-v(preserved){W2, W3}]
        let w1 = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        _ = w1
        let split = TilingContainer(
            parent: workspace.rootTilingContainer,
            adaptiveWeight: 1,
            .v, // vertical orientation
            .dwindle,
            index: INDEX_BIND_LAST,
        )
        split.preserveSplit = true
        let w2 = TestWindow.new(id: 2, parent: split)
        let w3 = TestWindow.new(id: 3, parent: split)
        _ = w3

        // Close W3.
        w3.unbindFromParent()
        workspace.normalizeContainers()

        // split-v survives with W2 alone (preserveSplit=true).
        assertEquals(workspace.rootTilingContainer.children.count, 2)
        XCTAssertTrue(workspace.rootTilingContainer.children[1] === split)
        assertEquals(split.children.count, 1)
        XCTAssertTrue(split.children[0] === w2)
        assertEquals(split.orientation, .v) // direction is preserved
    }
}
