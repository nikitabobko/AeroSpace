@testable import AppBundle
import Testing

@MainActor
@Suite(.serializedGlobally)
struct TreeNodeTest {
    init() { setUpWorkspacesForTests() }

    @Test func testChildParentCyclicReferenceMemoryLeak() {
        let workspace = Workspace.get(byName: name) // Don't cache root node
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        #expect(window.parent != nil)
        workspace.rootTilingContainer.unbindFromParent()
        #expect(window.parent == nil)
    }

    @Test func testIsEffectivelyEmpty() {
        let workspace = Workspace.get(byName: name)

        #expect(workspace.isEffectivelyEmpty)
        weak let window: TestWindow? = .new(id: 1, parent: workspace.rootTilingContainer)
        #expect(window != nil)
        #expect(!workspace.isEffectivelyEmpty)
        window!.unbindFromParent()
        #expect(workspace.isEffectivelyEmpty)

        // Don't save to local variable
        TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        #expect(!workspace.isEffectivelyEmpty)
    }

    @Test func testBindWeightAuto_skipsTombstones() {
        let root = Workspace.get(byName: name).rootTilingContainer
        TestWindow.new(id: 1, parent: root, adaptiveWeight: 2)
        TestWindow.new(id: 2, parent: root, adaptiveWeight: 10).lifeStatus = .invisible
        TestWindow.new(id: 3, parent: root, adaptiveWeight: 4)
        TilingContainer.newVTiles(parent: root, adaptiveWeight: 20).lifeStatus = .deadOrInvisible

        let window = TestWindow.new(id: 4, parent: root, adaptiveWeight: WEIGHT_AUTO)
        assertEquals(window.getWeight(root.orientation), 3) // (2 + 4) / 2
    }

    @Test func testBindWeightAuto_onlyTombstoneSiblings() {
        let root = Workspace.get(byName: name).rootTilingContainer
        TestWindow.new(id: 1, parent: root, adaptiveWeight: 10).lifeStatus = .dead

        let window = TestWindow.new(id: 2, parent: root, adaptiveWeight: WEIGHT_AUTO)
        assertEquals(window.getWeight(root.orientation), 1)
    }

    @Test func testNormalizeContainers_dontRemoveRoot() {
        let workspace = Workspace.get(byName: name)
        weak let root = workspace.rootTilingContainer
        func test() {
            #expect(root != nil)
            #expect(root!.isEffectivelyEmpty)
            workspace.normalizeContainers()
            #expect(root != nil)
        }
        test()

        config.enableNormalizationFlattenContainers = true
        test()
    }

    @Test func testNormalizeContainers_singleWindowChild() {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 0, parent: $0)
            TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 1, parent: $0)
            }
        }
        workspace.normalizeContainers()
        assertEquals(
            .h_tiles([.window(0), .window(1)]),
            workspace.rootTilingContainer.layoutDescription,
        )
    }

    @Test func testNormalizeContainers_rootSingleContainerChild() {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        var window3: TestWindow!
        workspace.rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 1, parent: $0)
                TestWindow.new(id: 2, parent: $0)
            }
            window3 = TestWindow.new(id: 3, parent: $0)
        }
        window3.unbindFromParent()
        workspace.normalizeContainers()
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .v_tiles([.window(1), .window(2)]),
        )
    }

    @Test func testNormalizeContainers_removeEffectivelyEmpty() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                _ = TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1)
            }
        }
        assertEquals(workspace.rootTilingContainer.children.count, 1)
        workspace.normalizeContainers()
        assertEquals(workspace.rootTilingContainer.children.count, 0)
    }

    @Test func testNormalizeContainers_flattenContainers() {
        let workspace = Workspace.get(byName: name) // Don't cache root node
        workspace.rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 1, parent: $0, adaptiveWeight: 1)
            }
        }
        workspace.normalizeContainers()
        #expect(workspace.rootTilingContainer.children.singleOrNil() is TilingContainer)

        config.enableNormalizationFlattenContainers = true
        workspace.normalizeContainers()
        #expect(workspace.rootTilingContainer.children.singleOrNil() is TestWindow)
    }

    @Test func testNormalizeMasterStack_disabledByDefault() {
        let workspace = Workspace.get(byName: name)
        for id in 0 ..< 3 {
            TestWindow.new(id: .init(UInt64(id)), parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        assertEquals(
            .h_tiles([.window(0), .window(1), .window(2)]),
            workspace.rootTilingContainer.layoutDescription,
        )
    }

    @Test func testNormalizeMasterStack_singleWindowIsUnchanged() {
        config.enableNormalizationMasterStack = true
        let workspace = Workspace.get(byName: name)
        TestWindow.new(id: 0, parent: workspace.rootTilingContainer)
        workspace.normalizeContainers()
        assertEquals(.h_tiles([.window(0)]), workspace.rootTilingContainer.layoutDescription)
    }

    @Test func testNormalizeMasterStack_masterAndStack() {
        config.enableNormalizationMasterStack = true
        let workspace = Workspace.get(byName: name)
        for id in 0 ..< 3 {
            TestWindow.new(id: .init(UInt64(id)), parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        assertEquals(
            .h_tiles([
                .window(0),
                .v_tiles([.window(1), .window(2)]),
            ]),
            workspace.rootTilingContainer.layoutDescription,
        )
    }

    @Test func testNormalizeMasterStack_severalMasters() {
        config.enableNormalizationMasterStack = true
        config.masterStackMasterCount = 2
        let workspace = Workspace.get(byName: name)
        for id in 0 ..< 3 {
            TestWindow.new(id: .init(UInt64(id)), parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        assertEquals(
            .h_tiles([
                .v_tiles([.window(0), .window(1)]),
                .window(2),
            ]),
            workspace.rootTilingContainer.layoutDescription,
        )
    }

    @Test func testNormalizeMasterStack_isIdempotentAndPreservesWeights() {
        config.enableNormalizationMasterStack = true
        let workspace = Workspace.get(byName: name)
        for id in 0 ..< 3 {
            TestWindow.new(id: .init(UInt64(id)), parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        let root = workspace.rootTilingContainer
        let masterColumn = root.children[0]
        assertEquals(0.5, masterColumn.getWeight(.h))

        masterColumn.setWeight(.h, 0.7)
        workspace.normalizeContainers()
        assertEquals(
            .h_tiles([
                .window(0),
                .v_tiles([.window(1), .window(2)]),
            ]),
            root.layoutDescription,
        )
        assertEquals(0.7, masterColumn.getWeight(.h))
    }

    @Test func testNormalizeMasterStack_masterWidthPercent() {
        config.enableNormalizationMasterStack = true
        config.masterStackMasterWidthPercent = 75
        let workspace = Workspace.get(byName: name)
        // Two windows already have the desired shape, so the width is applied
        // only when the normalization actually reshapes the workspace.
        for id in 0 ..< 3 {
            TestWindow.new(id: .init(UInt64(id)), parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        let root = workspace.rootTilingContainer
        assertEquals(0.75, root.children[0].getWeight(.h))
        assertEquals(0.25, root.children[1].getWeight(.h))
    }

    @Test func testNormalizeMasterStack_worksWithEnabledFlattenNormalization() {
        config.enableNormalizationMasterStack = true
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        for id in 0 ..< 4 {
            TestWindow.new(id: .init(UInt64(id)), parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        assertEquals(
            .h_tiles([
                .window(0),
                .v_tiles([.window(1), .window(2), .window(3)]),
            ]),
            workspace.rootTilingContainer.layoutDescription,
        )
    }

    @Test func testNormalizeMasterStack_skipsAccordionWorkspaces() {
        config.enableNormalizationMasterStack = true
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .accordion
        for id in 0 ..< 3 {
            TestWindow.new(id: .init(UInt64(id)), parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        assertEquals(
            .h_accordion([.window(0), .window(1), .window(2)]),
            workspace.rootTilingContainer.layoutDescription,
        )
    }
}
