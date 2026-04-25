@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
final class DwindleInsertionTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        // Reset dwindle config to defaults; individual tests opt into specific
        // knobs.
        config.dwindle = DwindleConfig()
    }

    // MARK: - decide() — pure orientation/side decision tests

    func testDecide_aspectRatioWiderThanTall_choosesHorizontal() {
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        let (orientation, side) = DwindleInsertion.decide(
            cursor: .zero,
            targetRect: rect,
            parentOrientation: .v,
            cfg: DwindleConfig(),
        )
        assertEquals(orientation, .h)
        assertEquals(side, 1) // .auto → second
    }

    func testDecide_aspectRatioTallerThanWide_choosesVertical() {
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 600, height: 800)
        let (orientation, _) = DwindleInsertion.decide(
            cursor: .zero,
            targetRect: rect,
            parentOrientation: .h,
            cfg: DwindleConfig(),
        )
        assertEquals(orientation, .v)
    }

    func testDecide_noRect_fallsBackToOppositeParent() {
        let (orientation, _) = DwindleInsertion.decide(
            cursor: .zero,
            targetRect: nil,
            parentOrientation: .h,
            cfg: DwindleConfig(),
        )
        assertEquals(orientation, .v)
    }

    func testDecide_forceSplitFirst_putsNewWindowOnSide0() {
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        var cfg = DwindleConfig()
        cfg.forceSplit = .first
        let (_, side) = DwindleInsertion.decide(
            cursor: .zero,
            targetRect: rect,
            parentOrientation: .v,
            cfg: cfg,
        )
        assertEquals(side, 0)
    }

    func testDecide_forceSplitSecond_putsNewWindowOnSide1() {
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        var cfg = DwindleConfig()
        cfg.forceSplit = .second
        let (_, side) = DwindleInsertion.decide(
            cursor: .zero,
            targetRect: rect,
            parentOrientation: .v,
            cfg: cfg,
        )
        assertEquals(side, 1)
    }

    // MARK: - smart-split cursor logic

    func testDecide_smartSplit_cursorOnLeftHalf_splitsLeft() {
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        var cfg = DwindleConfig()
        cfg.smartSplit = true
        let (orientation, side) = DwindleInsertion.decide(
            cursor: CGPoint(x: 100, y: 300),
            targetRect: rect,
            parentOrientation: .v,
            cfg: cfg,
        )
        assertEquals(orientation, .h)
        assertEquals(side, 0)
    }

    func testDecide_smartSplit_cursorOnRightHalf_splitsRight() {
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        var cfg = DwindleConfig()
        cfg.smartSplit = true
        let (orientation, side) = DwindleInsertion.decide(
            cursor: CGPoint(x: 700, y: 300),
            targetRect: rect,
            parentOrientation: .v,
            cfg: cfg,
        )
        assertEquals(orientation, .h)
        assertEquals(side, 1)
    }

    func testDecide_smartSplit_cursorOnTopHalf_splitsTop() {
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        var cfg = DwindleConfig()
        cfg.smartSplit = true
        let (orientation, side) = DwindleInsertion.decide(
            cursor: CGPoint(x: 400, y: 50),
            targetRect: rect,
            parentOrientation: .h,
            cfg: cfg,
        )
        assertEquals(orientation, .v)
        assertEquals(side, 0)
    }

    func testDecide_smartSplit_cursorOnBottomHalf_splitsBottom() {
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        var cfg = DwindleConfig()
        cfg.smartSplit = true
        let (orientation, side) = DwindleInsertion.decide(
            cursor: CGPoint(x: 400, y: 550),
            targetRect: rect,
            parentOrientation: .h,
            cfg: cfg,
        )
        assertEquals(orientation, .v)
        assertEquals(side, 1)
    }

    func testDecide_smartSplit_cursorOutsideRect_fallsBackToForceSplit() {
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        var cfg = DwindleConfig()
        cfg.smartSplit = true
        cfg.forceSplit = .first // would otherwise be .auto → side 1
        let (orientation, side) = DwindleInsertion.decide(
            cursor: CGPoint(x: 9999, y: 9999), // outside any reasonable rect
            targetRect: rect,
            parentOrientation: .v,
            cfg: cfg,
        )
        // Aspect ratio still picks orientation; force-split decides side.
        assertEquals(orientation, .h)
        assertEquals(side, 0) // force-split=first
    }

    // MARK: - compute() — full insertion side-effect tests

    func testCompute_emptyWorkspace_returnsNil() {
        // Empty workspace → no MRU target → compute returns nil and the caller
        // falls back to standard root-binding semantics.
        let workspace = Workspace.get(byName: name)
        let result = DwindleInsertion.compute(workspace: workspace)
        XCTAssertNil(result)
    }

    func testCompute_targetInTilesContainer_returnsNil() {
        // MRU target's parent is `.tiles`, not `.dwindle`. Dwindle should not
        // apply. Verifies the per-container layout-choice composition rule.
        let workspace = Workspace.get(byName: name)
        let target = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        target.markAsMostRecentChild()
        let result = DwindleInsertion.compute(workspace: workspace)
        XCTAssertNil(result)
    }

    func testCompute_targetInDwindleContainer_wrapsTarget() {
        // Single-window dwindle root → second window should wrap the first.
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        let target = TestWindow.new(
            id: 1,
            parent: workspace.rootTilingContainer,
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600),
        )
        target.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        target.markAsMostRecentChild()

        let result = DwindleInsertion.compute(workspace: workspace)
        XCTAssertNotNil(result)
        guard let result else { return }

        // Target was unbound and rebound under a new split TilingContainer.
        XCTAssertTrue(result.parent is TilingContainer)
        let split = result.parent as! TilingContainer
        assertEquals(split.layout, .dwindle)
        assertEquals(split.children.count, 1) // only target so far; caller binds the new window
        XCTAssertTrue(split.children[0] === target)
        // The new container sits in the root's child slot.
        assertEquals(workspace.rootTilingContainer.children.count, 1)
        XCTAssertTrue(workspace.rootTilingContainer.children[0] === split)
    }

    func testCompute_forceSplitFirst_newWindowAtIndex0() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        config.dwindle.forceSplit = .first
        let target = TestWindow.new(
            id: 1,
            parent: workspace.rootTilingContainer,
        )
        target.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        target.markAsMostRecentChild()

        let result = DwindleInsertion.compute(workspace: workspace)
        assertEquals(result?.index, 0)
    }

    func testCompute_forceSplitSecond_newWindowAtIndex1() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        config.dwindle.forceSplit = .second
        let target = TestWindow.new(
            id: 1,
            parent: workspace.rootTilingContainer,
        )
        target.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        target.markAsMostRecentChild()

        let result = DwindleInsertion.compute(workspace: workspace)
        assertEquals(result?.index, 1)
    }

    func testCompute_thirdWindow_buildsBinaryTree() {
        // Simulate the "3 windows produce a binary tree" scenario from the spec.
        // Existing tree: root(.dwindle, .h) → [W1, W2] with W2 focused (MRU).
        // Inserting W3 should wrap W2 in a new dwindle container → root → [W1, split{W2, W3}].
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        let w1 = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let w2 = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        w1.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 400, height: 600)
        w2.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 400, topLeftY: 0, width: 400, height: 600)
        w2.markAsMostRecentChild()

        let result = DwindleInsertion.compute(workspace: workspace)
        XCTAssertNotNil(result)
        guard let result else { return }

        // The wrap container replaces W2 in the root.
        assertEquals(workspace.rootTilingContainer.children.count, 2)
        XCTAssertTrue(workspace.rootTilingContainer.children[0] === w1)
        XCTAssertTrue(workspace.rootTilingContainer.children[1] === result.parent)
        let split = result.parent as! TilingContainer
        assertEquals(split.layout, .dwindle)
        XCTAssertTrue(split.children.contains(where: { $0 === w2 }))
        // result.index points at where the *new* (third) window will go.
        assertEquals(result.index, 1) // forceSplit=auto → side 1
    }

    // MARK: - default-split-ratio + split-width-multiplier weight calculations

    func testCompute_defaultRatio_producesEqualSplit() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        let target = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        target.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        target.markAsMostRecentChild()

        // Defaults: ratio = 0.5, multiplier = 1.0 → 0.5 effective
        let result = DwindleInsertion.compute(workspace: workspace)
        XCTAssertNotNil(result)
        // newWindowWeight + targetWeight should be ~total scale (100). Both equal.
        assertEquals(result?.adaptiveWeight, 50)
    }

    func testCompute_ratio_0_7_producesLargerNewPane() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        config.dwindle.defaultSplitRatio = 0.7
        let target = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        target.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        target.markAsMostRecentChild()

        let result = DwindleInsertion.compute(workspace: workspace)
        // ratio = 0.7 * 1.0 = 0.7. New window weight = 70.
        assertEquals(result?.adaptiveWeight, 70)
    }

    func testCompute_widthMultiplier_appliedOverRatio() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        config.dwindle.defaultSplitRatio = 0.5
        config.dwindle.splitWidthMultiplier = 1.4 // 0.5 * 1.4 = 0.7
        let target = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        target.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        target.markAsMostRecentChild()

        let result = DwindleInsertion.compute(workspace: workspace)
        assertEquals(result?.adaptiveWeight, 70)
    }

    func testCompute_extremeRatio_clampedTo95() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        config.dwindle.defaultSplitRatio = 0.99
        config.dwindle.splitWidthMultiplier = 2.0 // 0.99 * 2 = 1.98 → clamped to 0.95
        let target = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        target.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600)
        target.markAsMostRecentChild()

        let result = DwindleInsertion.compute(workspace: workspace)
        assertEquals(result?.adaptiveWeight, 95)
    }

    // MARK: - useActiveForSplits (default true path only — cursor logic isn't unit-testable)

    func testCompute_useActiveForSplits_default_targetsFocusedMRU() {
        // useActiveForSplits = true (default): target is workspace MRU.
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        let w1 = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let w2 = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        w1.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 400, height: 600)
        w2.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 400, topLeftY: 0, width: 400, height: 600)
        // Make w1 the MRU.
        w1.markAsMostRecentChild()
        XCTAssertTrue(workspace.mostRecentWindowRecursive === w1)

        let result = DwindleInsertion.compute(workspace: workspace)
        XCTAssertNotNil(result)
        // The wrap targeted w1 (the MRU), not w2.
        let split = result?.parent as? TilingContainer
        XCTAssertNotNil(split)
        XCTAssertTrue(split!.children.contains(where: { $0 === w1 }))
        XCTAssertFalse(split!.children.contains(where: { $0 === w2 }))
    }
}
