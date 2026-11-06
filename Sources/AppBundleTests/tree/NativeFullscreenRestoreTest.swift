@testable import AppBundle
import AppKit
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct NativeFullscreenRestoreTest {
    init() {
        setUpWorkspacesForTests()
        config.automaticallyUnhideMacosHiddenApps = true
        for window in macosPopupWindowsContainer.children + macosMinimizedWindowsContainer.children {
            window.unbindFromParent()
        }
    }

    @Test func testDetectedFullscreenRestoresAccordionOrder() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.layout = .accordion
        TestWindow.new(id: 1, parent: root)
        let browser = TestWindow.new(id: 2, parent: root)
        TestWindow.new(id: 3, parent: root)

        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        assertEquals(root.layoutDescription, .h_accordion([.window(1), .window(3)]))
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()

        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_accordion([.window(1), .window(2), .window(3)]))
    }

    @Test func testDetectedFullscreenRestoresTileSizesAfterLayout() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let left = TestWindow.new(id: 1, parent: root, adaptiveWeight: 200)
        let browser = TestWindow.new(id: 2, parent: root, adaptiveWeight: 300)
        let right = TestWindow.new(id: 3, parent: root, adaptiveWeight: 700)
        try await workspace.layoutWorkspace()
        let weights = [left, browser, right].map { $0.getWeight(.h) }

        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        try await workspace.layoutWorkspace()
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        try await workspace.layoutWorkspace()

        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([.window(1), .window(2), .window(3)]))
        for (window, weight) in zip([left, browser, right], weights) {
            #expect(abs(window.getWeight(.h) - weight) < 0.001)
        }
    }

    @Test(arguments: [false, true], [false, true])
    func testNestedContainerRestored(flatten: Bool, oppositeOrientation: Bool) async throws {
        config.enableNormalizationFlattenContainers = flatten
        config.enableNormalizationOppositeOrientationForNestedContainers = oppositeOrientation
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let left = TestWindow.new(id: 1, parent: root, adaptiveWeight: 300)
        let nested = TilingContainer.newVTiles(parent: root, adaptiveWeight: 700)
        let browser = TestWindow.new(id: 2, parent: nested, adaptiveWeight: 200)
        let bottom = TestWindow.new(id: 3, parent: nested, adaptiveWeight: 500)
        try await workspace.layoutWorkspace()
        let weights = [left.getWeight(.h), nested.getWeight(.h), browser.getWeight(.v), bottom.getWeight(.v)]

        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        workspace.normalizeContainers()
        try await workspace.layoutWorkspace()
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        workspace.normalizeContainers()
        try await workspace.layoutWorkspace()

        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([.window(1), .v_tiles([.window(2), .window(3)])]))
        let restoredWeights = [left.getWeight(.h), browser.parent!.getWeight(.h), browser.getWeight(.v), bottom.getWeight(.v)]
        for (actual, saved) in zip(restoredWeights, weights) { #expect(abs(actual - saved) < 0.001) }
    }

    @Test(arguments: [false, true])
    func testRootContentCopyIsReversed(oppositeOrientation: Bool) async throws {
        config.enableNormalizationFlattenContainers = true
        config.enableNormalizationOppositeOrientationForNestedContainers = oppositeOrientation
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.changeOrientation(.v)
        root.layout = .accordion
        let browser = TestWindow.new(id: 1, parent: root, adaptiveWeight: 200)
        let nested = TilingContainer(parent: root, adaptiveWeight: 400, .h, .accordion, index: INDEX_BIND_LAST)
        let chrome = TestWindow.new(id: 2, parent: nested, adaptiveWeight: 300)
        let slack = TestWindow.new(id: 3, parent: nested, adaptiveWeight: 500)

        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        workspace.normalizeContainers()
        #expect(workspace.rootTilingContainer === root)
        assertEquals(root.layoutDescription, .h_accordion([.window(2), .window(3)]))
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        workspace.normalizeContainers()

        assertEquals(workspace.rootTilingContainer.layoutDescription, .v_accordion([.window(1), .h_accordion([.window(2), .window(3)])]))
        assertEquals(browser.getWeight(.v), 200)
        assertEquals(chrome.parent!.getWeight(.v), 400)
        assertEquals(chrome.getWeight(.h), 300)
        assertEquals(slack.getWeight(.h), 500)
    }

    @Test func testMultipleNormalizationPasses() async throws {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let browser = TestWindow.new(id: 1, parent: root)
        let vertical = TilingContainer.newVTiles(parent: root, adaptiveWeight: 1)
        let horizontal = TilingContainer.newHTiles(parent: vertical, adaptiveWeight: 1)
        TestWindow.new(id: 2, parent: horizontal)
        TestWindow.new(id: 3, parent: horizontal)

        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        for _ in 0 ..< 3 { workspace.normalizeContainers() }
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()

        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([.window(1), .v_tiles([.h_tiles([.window(2), .window(3)])])]))
    }

    @Test(arguments: [false, true])
    func testCommandRestoresPositionWithoutWaitingForDetection(waitForDetection: Bool) async throws {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        TestWindow.new(id: 1, parent: root)
        let nested = TilingContainer.newVTiles(parent: root, adaptiveWeight: 1)
        let browser = TestWindow.new(id: 2, parent: nested)
        TestWindow.new(id: 3, parent: nested)
        #expect(browser.focusWindow())

        for _ in 0 ..< 3 {
            let entered = await parseCommand("macos-native-fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
            #expect(entered.exitCode.rawValue == 0)
            #expect(browser.parent === workspace.macOsNativeFullscreenWindowsContainer)
            if waitForDetection { try await normalizeLayoutReason() }
            workspace.normalizeContainers()
            let exited = await parseCommand("macos-native-fullscreen off").cmdOrDie.run(.defaultEnv, .emptyStdin)
            #expect(exited.exitCode.rawValue == 0)
            #expect(browser.layoutReason == .standard)
            assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([.window(1), .v_tiles([.window(2), .window(3)])]))
        }
    }

    @Test func testAddedWindowFallsBack() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        TestWindow.new(id: 1, parent: root)
        let browser = TestWindow.new(id: 2, parent: root)
        TestWindow.new(id: 3, parent: root)
        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        TestWindow.new(id: 4, parent: root)
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(3), .window(4), .window(2)]))
    }

    @Test func testMovedSiblingFallsBack() async throws {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        TestWindow.new(id: 1, parent: root)
        let nested = TilingContainer.newVTiles(parent: root, adaptiveWeight: 1)
        let browser = TestWindow.new(id: 2, parent: nested)
        let sibling = TestWindow.new(id: 3, parent: nested)
        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        workspace.normalizeContainers()
        let destination = TilingContainer.newVTiles(parent: root, adaptiveWeight: 1)
        sibling.bind(to: destination, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        #expect(browser.parent === destination)
        #expect(sibling.parent === destination)
        #expect(!nested.isBound)
    }

    @Test func testClosedSiblingIsNotResurrected() async throws {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        TestWindow.new(id: 1, parent: root)
        let browser = TestWindow.new(id: 2, parent: root)
        let sibling = TestWindow.new(id: 3, parent: root)
        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        sibling.closeAxWindow()
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))
        #expect(sibling.parent == nil)
    }

    @Test func testResizedSiblingKeepsItsNewWeight() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let left = TestWindow.new(id: 1, parent: root, adaptiveWeight: 200)
        let browser = TestWindow.new(id: 2, parent: root, adaptiveWeight: 400)
        let right = TestWindow.new(id: 3, parent: root, adaptiveWeight: 600)
        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        left.setWeight(.h, 250)
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        assertEquals(left.getWeight(.h), 250)
        assertEquals(right.getWeight(.h), 600)
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(3), .window(2)]))
    }

    @Test func testChangedLayoutIsPreserved() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let browser = TestWindow.new(id: 1, parent: root)
        TestWindow.new(id: 2, parent: root)
        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        root.layout = .accordion
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        assertEquals(root.layoutDescription, .h_accordion([.window(2), .window(1)]))
    }

    @Test func testEditsInsideUnaffectedSubtreeArePreserved() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let browser = TestWindow.new(id: 1, parent: root)
        TestWindow.new(id: 2, parent: root)
        let nested = TilingContainer.newVTiles(parent: root, adaptiveWeight: 1)
        TestWindow.new(id: 3, parent: nested)
        TestWindow.new(id: 4, parent: nested)
        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        TestWindow.new(id: 5, parent: nested)
        nested.layout = .accordion
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2), .v_accordion([.window(3), .window(4), .window(5)])]))
    }

    @Test func testOnlyWindowAndWorkspaceSwitch() async throws {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        let browser = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        workspace.normalizeContainers()
        #expect(Workspace.get(byName: "other").focusWorkspace())
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        #expect(browser.nodeWorkspace === workspace)
        #expect(globalFocus.workspace.name == "other")
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([.window(1)]))
    }

    @Test func testFloatingWindowStaysFloating() async throws {
        let workspace = Workspace.get(byName: name)
        let browser = TestWindow.new(id: 1, parent: workspace.floatingWindowsContainer)
        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        #expect(browser.parent === workspace.floatingWindowsContainer)
    }

    @Test func testReturningNestedWindowIsMostRecent() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.layout = .accordion
        let nested = TilingContainer.newVTiles(parent: root, adaptiveWeight: 1)
        let browser = TestWindow.new(id: 1, parent: nested)
        TestWindow.new(id: 2, parent: nested)
        TestWindow.new(id: 3, parent: root)
        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        #expect(root.mostRecentWindowRecursive === browser)
    }

    @Test func testFallbackDoesNotLeaveStaleRestorePoint() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let browser = TestWindow.new(id: 1, parent: root)
        TestWindow.new(id: 2, parent: root)
        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        TestWindow.new(id: 3, parent: root)
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        browser.bind(to: root, adaptiveWeight: 1, index: 0)
        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2), .window(3)]))
    }

    @Test func testChangedNormalizationConfigurationFallsBack() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let browser = TestWindow.new(id: 1, parent: root)
        TestWindow.new(id: 2, parent: root)
        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        config.enableNormalizationFlattenContainers.toggle()
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        assertEquals(root.layoutDescription, .h_tiles([.window(2), .window(1)]))
    }

    @Test(arguments: [false, true])
    func testInvisibleSiblingDoesNotInvalidateRestoration(accordion: Bool) async throws {
        config.enableNormalizationFlattenContainers = true
        config.enableNormalizationOppositeOrientationForNestedContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.layout = accordion ? .accordion : .tiles
        let left = TestWindow.new(id: 1, parent: root, adaptiveWeight: 200)
        let browser = TestWindow.new(id: 2, parent: root, adaptiveWeight: 300)
        let invisible = TestWindow.new(id: 3, parent: root, adaptiveWeight: 400)
        invisible.lifeStatus = .invisible
        let right = TestWindow.new(id: 4, parent: root, adaptiveWeight: 500)
        try await workspace.layoutWorkspace()
        let weights = [left, browser, right].map { $0.getWeight(.h) }

        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        workspace.normalizeContainers()
        try await workspace.layoutWorkspace()
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        try await workspace.layoutWorkspace()

        let windows: [LayoutDescription] = [.window(1), .window(2), .window(3), .window(4)]
        assertEquals(root.layoutDescription, accordion ? .h_accordion(windows) : .h_tiles(windows))
        for (window, weight) in zip([left, browser, right], weights) {
            #expect(abs(window.getWeight(.h) - weight) < 0.001)
        }
        #expect(invisible.lifeStatus == .invisible)
    }

    @Test func testSpaceTransitionWaitsBeforeRestoringWeights() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let browser = TestWindow.new(id: 1, parent: root, adaptiveWeight: 1106.5)
        let terminal = TestWindow.new(id: 2, parent: root, adaptiveWeight: 611.5)
        try await workspace.layoutWorkspace()
        let browserWeight = browser.getWeight(.h)
        let terminalWeight = terminal.getWeight(.h)

        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        try await workspace.layoutWorkspace()
        terminal.lifeStatus = .invisible
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        #expect(browser.parent === workspace.macOsNativeFullscreenWindowsContainer)
        #expect(browser.layoutReason == .macos(prevParentKind: .tilingContainer))
        try await workspace.layoutWorkspace()

        terminal.lifeStatus = .alive
        try await normalizeLayoutReason()
        try await workspace.layoutWorkspace()
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))
        #expect(abs(browser.getWeight(.h) - browserWeight) < 0.001)
        #expect(abs(terminal.getWeight(.h) - terminalWeight) < 0.001)
    }

    @Test func testSpaceTransitionWaitHasABound() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let browser = TestWindow.new(id: 1, parent: root)
        let terminal = TestWindow.new(id: 2, parent: root)
        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        terminal.lifeStatus = .invisible
        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        #expect(browser.parent === workspace.macOsNativeFullscreenWindowsContainer)
        try await Task.sleep(for: .milliseconds(3100))
        try await normalizeLayoutReason()
        #expect(browser.parent === root)
        #expect(browser.layoutReason == .standard)
    }

    @Test(arguments: [false, true])
    func testFullscreenWindowChangesAreNotNativeTabSwaps(entering: Bool) {
        let browser: UInt32 = 71104
        let auxiliary: UInt32 = 79035
        let previous: [UInt32: WindowLifeStatus] = entering ? [browser: .alive] : [browser: .invisible, auxiliary: .alive]
        let current: [UInt32: WindowLifeStatus] = entering ? [browser: .invisible, auxiliary: .alive] : [browser: .alive]
        // These are the native IDs and visibility transitions from the live trace.
        // The unrestricted heuristic would give the browser identity to a popup.
        #expect(nativeTabSwapCandidate(previous: previous, current: current) != nil)
        #expect(nativeTabSwapCandidate(previous: previous, current: current, excluded: [browser]) == nil)
        #expect(nativeTabSwapCandidate(previous: previous, current: current, excluded: [auxiliary]) == nil)
    }

    @Test func testOrdinaryNativeTabSwapStillHasACandidate() {
        let candidate = nativeTabSwapCandidate(previous: [1: .alive, 2: .invisible], current: [1: .invisible, 2: .alive])
        #expect(candidate?.background == 1)
        #expect(candidate?.foreground == 2)
    }

    @Test func testBrowserAboveSmallTerminalAndTwoTerminalsOnRight() async throws {
        config.enableNormalizationFlattenContainers = true
        config.enableNormalizationOppositeOrientationForNestedContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let left = TilingContainer.newVTiles(parent: root, adaptiveWeight: 1100)
        let browser = TestWindow.new(id: 1, parent: left, adaptiveWeight: 900)
        let smallTerminal = TestWindow.new(id: 2, parent: left, adaptiveWeight: 150)
        let right = TilingContainer.newVTiles(parent: root, adaptiveWeight: 600)
        let upperRight = TestWindow.new(id: 3, parent: right, adaptiveWeight: 500)
        let lowerRight = TestWindow.new(id: 4, parent: right, adaptiveWeight: 550)
        try await workspace.layoutWorkspace()
        let columnWeights = [left.getWeight(.h), right.getWeight(.h)]
        let windows = [browser, smallTerminal, upperRight, lowerRight]
        let heights = windows.map { $0.getWeight(.v) }

        browser.isMacosFullscreenForTest = true
        try await normalizeLayoutReason()
        workspace.normalizeContainers()
        try await workspace.layoutWorkspace()
        for terminal in [smallTerminal, upperRight, lowerRight] { terminal.lifeStatus = .invisible }
        try await normalizeLayoutReason()
        workspace.normalizeContainers()
        try await workspace.layoutWorkspace()

        browser.isMacosFullscreenForTest = false
        try await normalizeLayoutReason()
        workspace.normalizeContainers()
        try await workspace.layoutWorkspace()
        #expect(browser.parent === workspace.macOsNativeFullscreenWindowsContainer)

        for terminal in [smallTerminal, upperRight, lowerRight] { terminal.lifeStatus = .alive }
        try await normalizeLayoutReason()
        workspace.normalizeContainers()
        try await workspace.layoutWorkspace()
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([
            .v_tiles([.window(1), .window(2)]),
            .v_tiles([.window(3), .window(4)]),
        ]))
        for (window, height) in zip(windows, heights) { #expect(abs(window.getWeight(.v) - height) < 0.001) }
        #expect(abs(browser.parent!.getWeight(.h) - columnWeights[0]) < 0.001)
        #expect(abs(upperRight.parent!.getWeight(.h) - columnWeights[1]) < 0.001)
    }
}
