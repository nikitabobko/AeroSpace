@testable import AppBundle
import XCTest

@MainActor
final class TreeNodeTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testChildParentCyclicReferenceMemoryLeak() {
        let workspace = Workspace.get(byName: name) // Don't cache root node
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        XCTAssertTrue(window.parent != nil)
        workspace.rootTilingContainer.unbindFromParent()
        XCTAssertTrue(window.parent == nil)
    }

    func testIsEffectivelyEmpty() {
        let workspace = Workspace.get(byName: name)

        XCTAssertTrue(workspace.isEffectivelyEmpty)
        weak let window: TestWindow? = .new(id: 1, parent: workspace.rootTilingContainer)
        XCTAssertNotEqual(window, nil)
        XCTAssertTrue(!workspace.isEffectivelyEmpty)
        window!.unbindFromParent()
        XCTAssertTrue(workspace.isEffectivelyEmpty)

        // Don't save to local variable
        TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        XCTAssertTrue(!workspace.isEffectivelyEmpty)
    }

    func testNormalizeContainers_dontRemoveRoot() {
        let workspace = Workspace.get(byName: name)
        weak let root = workspace.rootTilingContainer
        func test() {
            XCTAssertNotEqual(root, nil)
            XCTAssertTrue(root!.isEffectivelyEmpty)
            workspace.normalizeContainers()
            XCTAssertNotEqual(root, nil)
        }
        test()

        config.enableNormalizationFlattenContainers = true
        test()
    }

    func testNormalizeContainers_singleWindowChild() {
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

    func testNormalizeContainers_removeEffectivelyEmpty() {
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

    func testNormalizeContainers_bsp_forceBinary() {
        config.enableNormalizationBinaryTree = true
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
            TestWindow.new(id: 4, parent: $0)
        }
        workspace.normalizeContainers()
        // 1920x1080 → root .h; split → first child rect is half-width 960x1080 → .v; next .h; etc.
        assertEquals(
            .h_tiles([
                .window(1),
                .v_tiles([
                    .window(2),
                    .h_tiles([.window(3), .window(4)]),
                ]),
            ]),
            workspace.rootTilingContainer.layoutDescription,
        )
    }

    func testNormalizeContainers_bsp_orientsByRect() {
        config.enableNormalizationBinaryTree = true
        let workspace = Workspace.get(byName: name)
        // Start with the "wrong" orientation; BSP should flip it.
        workspace.rootTilingContainer.apply {
            $0.setOrientation(.v)
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
        }
        workspace.normalizeContainers()
        // 1920x1080 wide → .h
        assertEquals(
            .h_tiles([.window(1), .window(2)]),
            workspace.rootTilingContainer.layoutDescription,
        )
    }

    func testNormalizeContainers_flattenContainers() {
        let workspace = Workspace.get(byName: name) // Don't cache root node
        workspace.rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 1, parent: $0, adaptiveWeight: 1)
            }
        }
        workspace.normalizeContainers()
        XCTAssertTrue(workspace.rootTilingContainer.children.singleOrNil() is TilingContainer)

        config.enableNormalizationFlattenContainers = true
        workspace.normalizeContainers()
        XCTAssertTrue(workspace.rootTilingContainer.children.singleOrNil() is TestWindow)
    }
}
