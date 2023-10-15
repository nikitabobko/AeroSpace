import XCTest
@testable import AeroSpace_Debug

final class TreeNodeTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testChildParentCyclicReferenceMemoryLeak() {
        let workspace = Workspace.get(byName: name) // Don't cache root node
        let window = TestWindow(id: 1, parent: workspace.rootTilingContainer)

        XCTAssertTrue(window.parentOrNilForTests != nil)
        workspace.rootTilingContainer.unbindFromParent()
        XCTAssertTrue(window.parentOrNilForTests == nil)
    }

    func testIsEffectivelyEmpty() {
        let workspace = Workspace.get(byName: name)

        XCTAssertTrue(workspace.isEffectivelyEmpty)
        weak var window: TestWindow? = TestWindow(id: 1, parent: workspace.rootTilingContainer)
        XCTAssertNotEqual(window, nil)
        XCTAssertTrue(!workspace.isEffectivelyEmpty)
        window!.unbindFromParent()
        XCTAssertTrue(workspace.isEffectivelyEmpty)

        // Don't save to local variable
        TestWindow(id: 2, parent: workspace.rootTilingContainer)
        XCTAssertTrue(!workspace.isEffectivelyEmpty)
    }

    func testNormalizeContainers_dontRemoveRoot() {
        weak var root = Workspace.get(byName: name).rootTilingContainer
        XCTAssertNotEqual(root, nil)
        XCTAssertTrue(root!.isEffectivelyEmpty)
        root?.normalizeContainersRecursive()
        XCTAssertNotEqual(root, nil)
    }

    func testNormalizeContainers_removeEffectivelyEmpty() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVList(parent: $0, adaptiveWeight: 1).apply {
                let _ = TilingContainer.newHList(parent: $0, adaptiveWeight: 1)
            }
        }
        XCTAssertEqual(root.children.count, 1)
        root.normalizeContainersRecursive()
        XCTAssertEqual(root.children.count, 0)
    }

    func testNormalizeContainers_flattenContainers() {
        let workspace = Workspace.get(byName: name) // Don't cache root node
        workspace.rootTilingContainer.apply {
            TilingContainer.newVList(parent: $0, adaptiveWeight: 1).apply {
                TestWindow(id: 1, parent: $0, adaptiveWeight: 1)
            }
        }
        workspace.rootTilingContainer.normalizeContainersRecursive()
        XCTAssertTrue(workspace.rootTilingContainer.children.singleOrNil() is TilingContainer)

        config.autoFlattenContainers = true
        workspace.rootTilingContainer.normalizeContainersRecursive()
        XCTAssertTrue(workspace.rootTilingContainer.children.singleOrNil() is TestWindow)
    }

    //func testBindNotEmptyContainer_updatesAssignedMonitor() { // todo Uncomment once Monitor mock is ready
    //    let workspace = Workspace.get(byName: name)
    //    XCTAssertTrue(workspace.assignedMonitor == nil)
    //    TestWindow(id: 1, parent: workspace.rootTilingContainer)
    //    XCTAssertTrue(workspace.assignedMonitor != nil)
    //
    //    let container = workspace.rootTilingContainer
    //    XCTAssertEqual(container, workspace.rootTilingContainer)
    //    container.unbindFromParent()
    //    XCTAssertNotEqual(container, workspace.rootTilingContainer)
    //    XCTAssertTrue(workspace.assignedMonitor == nil)
    //
    //    container.bindTo(parent: workspace, adaptiveWeight: 1)
    //    XCTAssertTrue(workspace.assignedMonitor != nil)
    //}
}
