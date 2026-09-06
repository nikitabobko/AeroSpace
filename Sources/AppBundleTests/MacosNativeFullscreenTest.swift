@testable import AppBundle
import XCTest

@MainActor
final class MacosNativeFullscreenTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        config.automaticallyUnhideMacosHiddenApps = true
        for child in macosMinimizedWindowsContainer.children + macosPopupWindowsContainer.children {
            child.unbindFromParent()
        }
    }

    func testDetectedFullscreenRestoresAccordionOrder() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.changeOrientation(.v)
        root.layout = .accordion
        TestWindow.new(id: 1, parent: root)
        let fullscreen = TestWindow.new(id: 2, parent: root)
        TestWindow.new(id: 3, parent: root)

        assertEquals(root.layoutDescription, .v_accordion([.window(1), .window(2), .window(3)]))

        fullscreen.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()

        assertEquals(root.layoutDescription, .v_accordion([.window(1), .window(3)]))
        assertEquals(workspace.macOsNativeFullscreenWindowsContainer.children, [fullscreen])

        fullscreen.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()

        assertEquals(root.layoutDescription, .v_accordion([.window(1), .window(2), .window(3)]))
    }

    func testDetectedFullscreenRestoresTilePositionAndWeights() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let left = TestWindow.new(id: 1, parent: root, adaptiveWeight: 100)
        let fullscreen = TestWindow.new(id: 2, parent: root, adaptiveWeight: 200)
        let right = TestWindow.new(id: 3, parent: root, adaptiveWeight: 300)

        fullscreen.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        left.setWeight(.h, 250)
        right.setWeight(.h, 450)

        fullscreen.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()

        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2), .window(3)]))
        assertEquals(left.getWeight(.h), 100)
        assertEquals(fullscreen.getWeight(.h), 200)
        assertEquals(right.getWeight(.h), 300)
    }

    func testDetectedFullscreenRestoresParentFlattenedByNormalization() async throws {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.changeOrientation(.v)
        root.layout = .accordion
        TestWindow.new(id: 1, parent: root, adaptiveWeight: 100)
        let originalParent = TilingContainer(
            parent: root,
            adaptiveWeight: 300,
            .h,
            .accordion,
            index: INDEX_BIND_LAST,
        )
        let fullscreen = TestWindow.new(id: 2, parent: originalParent, adaptiveWeight: 200)
        let sibling = TestWindow.new(id: 3, parent: originalParent, adaptiveWeight: 400)

        fullscreen.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        workspace.normalizeContainers()

        XCTAssertFalse(originalParent.isBound)
        assertEquals(root.layoutDescription, .v_accordion([.window(1), .window(3)]))

        fullscreen.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()

        assertEquals(
            root.layoutDescription,
            .v_accordion([.window(1), .h_accordion([.window(2), .window(3)])]),
        )
        XCTAssertTrue(originalParent.isBound)
        guard originalParent.isBound else { return }
        assertEquals(originalParent.getWeight(.v), 300)
        assertEquals(fullscreen.getWeight(.h), 200)
        assertEquals(sibling.getWeight(.h), 400)
    }

    func testDetectedFullscreenRestoresRootFlattenedByNormalization() async throws {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.changeOrientation(.v)
        root.layout = .accordion
        let fullscreen = TestWindow.new(id: 1, parent: root, adaptiveWeight: 200)
        let right = TilingContainer(
            parent: root,
            adaptiveWeight: 400,
            .h,
            .accordion,
            index: INDEX_BIND_LAST,
        )
        let chrome = TestWindow.new(id: 2, parent: right, adaptiveWeight: 300)
        let slack = TestWindow.new(id: 3, parent: right, adaptiveWeight: 500)

        assertEquals(
            root.layoutDescription,
            .v_accordion([.window(1), .h_accordion([.window(2), .window(3)])]),
        )

        fullscreen.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        workspace.normalizeContainers()

        XCTAssertFalse(root.isBound)
        XCTAssertTrue(workspace.rootTilingContainer === right)

        fullscreen.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()

        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .v_accordion([.window(1), .h_accordion([.window(2), .window(3)])]),
        )
        XCTAssertTrue(root.isBound)
        guard root.isBound else { return }
        XCTAssertTrue(workspace.rootTilingContainer === root)
        assertEquals(fullscreen.getWeight(.v), 200)
        assertEquals(right.getWeight(.v), 400)
        assertEquals(chrome.getWeight(.h), 300)
        assertEquals(slack.getWeight(.h), 500)
    }

    func testCommandFullscreenRestoresOriginalPosition() async {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        TestWindow.new(id: 1, parent: root)
        let originalParent = TilingContainer.newVTiles(parent: root, adaptiveWeight: 1)
        let fullscreen = TestWindow.new(id: 2, parent: originalParent)
        TestWindow.new(id: 3, parent: originalParent)
        assertTrue(fullscreen.focusWindow())

        let enterResult = await parseCommand("macos-native-fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(enterResult.exitCode.rawValue, 0)
        workspace.normalizeContainers()
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(3)]))

        let exitResult = await parseCommand("macos-native-fullscreen off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(exitResult.exitCode.rawValue, 0)
        assertEquals(
            root.layoutDescription,
            .h_tiles([.window(1), .v_tiles([.window(2), .window(3)])]),
        )
    }

    func testChangedOriginalParentFallsBack() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        TestWindow.new(id: 1, parent: root)
        let fullscreen = TestWindow.new(id: 2, parent: root)
        TestWindow.new(id: 3, parent: root)

        fullscreen.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        TestWindow.new(id: 4, parent: root)

        fullscreen.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()

        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(3), .window(4), .window(2)]))
    }

    func testMissingOriginalParentFallsBack() async throws {
        let workspace = Workspace.get(byName: name)
        let originalParent = TilingContainer.newVTiles(parent: workspace.rootTilingContainer, adaptiveWeight: 1)
        TestWindow.new(id: 1, parent: originalParent)
        let fullscreen = TestWindow.new(id: 2, parent: originalParent)

        fullscreen.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        originalParent.unbindFromParent()

        fullscreen.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()

        XCTAssertTrue(fullscreen.parent === workspace.rootTilingContainer)
        XCTAssertFalse(originalParent.isBound)
    }

    func testMovingAdjacentWindowFallsBackWithoutCrash() async throws {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        TestWindow.new(id: 1, parent: root)
        let originalParent = TilingContainer.newVTiles(parent: root, adaptiveWeight: 1)
        let fullscreen = TestWindow.new(id: 2, parent: originalParent)
        let right = TestWindow.new(id: 3, parent: originalParent)

        fullscreen.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        workspace.normalizeContainers()
        let movedTo = TilingContainer.newVTiles(parent: root, adaptiveWeight: 1)
        right.bind(to: movedTo, adaptiveWeight: 1, index: INDEX_BIND_LAST)

        fullscreen.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()

        XCTAssertTrue(fullscreen.parent === movedTo)
        XCTAssertTrue(right.parent === movedTo)
        XCTAssertFalse(originalParent.isBound)
    }

    func testClosingAdjacentWindowFallsBackWithoutCrash() async throws {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let left = TestWindow.new(id: 1, parent: root)
        let originalParent = TilingContainer.newVTiles(parent: root, adaptiveWeight: 1)
        let fullscreen = TestWindow.new(id: 2, parent: originalParent)
        let right = TestWindow.new(id: 3, parent: originalParent)

        fullscreen.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        workspace.normalizeContainers()
        right.closeAxWindow()

        fullscreen.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()

        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))
        XCTAssertTrue(left.parent === root)
        XCTAssertTrue(fullscreen.parent === root)
        XCTAssertFalse(originalParent.isBound)
        assertNil(right.parent)
    }
}
