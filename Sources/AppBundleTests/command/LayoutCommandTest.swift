@testable import AppBundle
import Common
import XCTest

@MainActor
final class LayoutCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        assertNil(parseCommand("layout v_tiles h_tiles").errorOrNil)
        assertNil(parseCommand("layout tiling").errorOrNil)
        assertNil(parseCommand("layout floating tiling").errorOrNil)
        assertNil(parseCommand("layout --window-id 1 horizontal vertical").errorOrNil)

        testParseCommandFail(
            "layout --root accordion tiling",
            msg: "layout command: --root and tiling|floating are incompatible",
            exitCode: 2,
        )
        testParseSingleCommandSucc(
            "layout --root accordion tiles",
            LayoutCmdArgs(rawArgs: [], toggleBetween: [.accordion, .tiles]).copy(\.root, true),
        )
        testParseCommandFail(
            "layout --workspace 2 tiles",
            msg: "--workspace flag requires using an explicit --root flag",
            exitCode: 2,
        )
        testParseCommandFail(
            "layout --workspace 2 --window-id 2 tiles",
            msg: "ERROR: Conflicting options: --window-id, --workspace",
            exitCode: 2,
        )
        testParseCommandFail(
            "layout --fail-if-noop accordion tiling",
            msg: "--fail-if-noop allows only one <target-layout> argument",
            exitCode: 2,
        )
    }

    func testChangeOrientation() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }
        assertEquals(root.orientation, .h)

        await parseCommand("layout vertical").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.orientation, .v)
        assertEquals(root.layoutDescription, .v_tiles([.window(1), .window(2)]))
    }

    func testChangeLayoutToAccordion() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }
        assertEquals(root.layout, .tiles)

        await parseCommand("layout accordion").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layout, .accordion)
        assertEquals(root.layoutDescription, .h_accordion([.window(1), .window(2)]))
    }

    func testChangeBothLayoutAndOrientation() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        await parseCommand("layout v_accordion").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layout, .accordion)
        assertEquals(root.orientation, .v)
        assertEquals(root.layoutDescription, .v_accordion([.window(1), .window(2)]))
    }

    func testToggleBetween_skipsMatching() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        await parseCommand("layout h_tiles h_accordion").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layout, .accordion)
        assertEquals(root.orientation, .h)
    }

    func testToggleBetween_allMatch_fails() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        let result = await parseCommand("layout h_tiles").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))
    }

    func testEmptyWorkspace_changeOrientation() async {
        let workspace = Workspace.get(byName: name)
        assertTrue(workspace.isEffectivelyEmpty)

        let result = await parseCommand("layout v_tiles").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(name), .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(workspace.rootTilingContainer.orientation, .v)
        assertEquals(workspace.rootTilingContainer.layout, .tiles)
    }

    func testEmptyWorkspace_changeLayout() async {
        let workspace = Workspace.get(byName: name)
        assertTrue(workspace.isEffectivelyEmpty)

        let result = await parseCommand("layout accordion").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(name), .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(workspace.rootTilingContainer.layout, .accordion)
        assertEquals(workspace.rootTilingContainer.orientation, .h)
    }

    func testEmptyWorkspace_alreadyMatches_fails() async {
        let workspace = Workspace.get(byName: name)
        assertTrue(workspace.isEffectivelyEmpty)

        let result = await parseCommand("layout h_tiles").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(name), .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(workspace.rootTilingContainer.layout, .tiles)
        assertEquals(workspace.rootTilingContainer.orientation, .h)
    }

    func testEmptyWorkspace_floating_fails() async {
        let workspace = Workspace.get(byName: name)
        let result = await parseCommand("layout floating").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(name), .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [noWindowIsFocused])
        assertTrue(workspace.isEffectivelyEmpty)
    }

    func testEmptyWorkspace_tiling_fails() async {
        let workspace = Workspace.get(byName: name)
        let result = await parseCommand("layout tiling").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(name), .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, ["Already in the requested tiling mode. Tip: use --fail-if-noop to exit with non-zero exit code"])
        assertTrue(workspace.isEffectivelyEmpty)
    }

    func testEmptyWorkspace_tiling_failIfNoop() async {
        let workspace = Workspace.get(byName: name)
        let result = await parseCommand("layout tiling --fail-if-noop").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(name), .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [])
        assertTrue(workspace.isEffectivelyEmpty)
    }

    func testTilingToFloating() async {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        await parseCommand("layout floating").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(2)]))
        assertEquals(workspace.floatingWindows.map(\.windowId), [1])
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFloatingToTiling() async {
        let workspace = Workspace.get(byName: name)
        workspace.floatingWindowsContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }
        assertEquals(workspace.floatingWindows.map(\.windowId), [1])

        await parseCommand("layout tiling").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(workspace.floatingWindows, [])
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([.window(1)]))
    }

    func testLayoutTilingOnTiledWindow_isNoop() async {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        let result = await parseCommand("layout tiling").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))
    }

    func testLayoutFloatingOnFloatingWindow_isNoop() async {
        let workspace = Workspace.get(byName: name)
        workspace.floatingWindowsContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }

        let result = await parseCommand("layout floating").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(workspace.floatingWindows.map(\.windowId), [1])
    }

    func testChangeTilingLayoutOnFloatingWindow_fails() async {
        let workspace = Workspace.get(byName: name)
        workspace.floatingWindowsContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }

        let result = await parseCommand("layout v_tiles").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["The window is non-tiling"])
        assertEquals(workspace.floatingWindows.map(\.windowId), [1])
    }

    func testTogglesAcrossFloatingAndTiling() async {
        let workspace = Workspace.get(byName: name)
        workspace.floatingWindowsContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }

        // The window is floating, so [.floating, .tiling] picks .tiling
        await parseCommand("layout floating tiling").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([.window(1)]))

        // Now it's tiled, so the same toggle picks .floating
        await parseCommand("layout floating tiling").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(workspace.floatingWindows.map(\.windowId), [1])
    }

    func testRoot_changesRootInsteadOfNestedParent() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            }
            TestWindow.new(id: 2, parent: $0)
        }
        assertEquals(root.orientation, .h)
        assertEquals(root.layout, .tiles)

        await parseCommand("layout --root v_accordion").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layout, .accordion)
        assertEquals(root.orientation, .v)
        assertEquals(root.layoutDescription, .v_accordion([
            .v_tiles([.window(1)]),
            .window(2),
        ]))
    }

    func testRoot_emptyWorkspace_changeLayout() async {
        let workspace = Workspace.get(byName: name)
        assertTrue(workspace.isEffectivelyEmpty)

        let result = await parseCommand("layout --root accordion").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(name), .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(workspace.rootTilingContainer.layout, .accordion)
        assertEquals(workspace.rootTilingContainer.orientation, .h)
    }

    func testRoot_floatingFocusedWindow_changesRootTilingContainer() async {
        let workspace = Workspace.get(byName: name)
        workspace.floatingWindowsContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }

        await parseCommand("layout --root v_accordion").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(workspace.rootTilingContainer.layout, .accordion)
        assertEquals(workspace.rootTilingContainer.orientation, .v)
        assertEquals(workspace.floatingWindows.map(\.windowId), [1])
    }

    func testRoot_macosFullscreenFocusedWindow_changesRootTilingContainer() async {
        let workspace = Workspace.get(byName: name)
        assertEquals(TestWindow.new(id: 1, parent: workspace.macOsNativeFullscreenWindowsContainer).focusWindow(), true)

        // Without --root this would fail with "Can't change layout for macOS minimized, fullscreen…".
        await parseCommand("layout --root v_accordion").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(workspace.rootTilingContainer.layout, .accordion)
        assertEquals(workspace.rootTilingContainer.orientation, .v)
    }

    func testRoot_withWindowIdFlag_targetsThatWindowsWorkspaceRoot() async {
        let focusedRoot = Workspace.get(byName: "a").rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }
        let otherRoot = Workspace.get(byName: "b").rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
        }
        assertEquals(focusedRoot.layout, .tiles)
        assertEquals(otherRoot.layout, .tiles)

        await parseCommand("layout --root --window-id 2 v_accordion").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(otherRoot.layout, .accordion)
        assertEquals(otherRoot.orientation, .v)
        assertEquals(focusedRoot.layout, .tiles) // Focused workspace must be untouched
    }

    func testRoot_withWorkspaceFlag_targetsThatWorkspace() async {
        let focusedRoot = Workspace.get(byName: "a").rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }
        let otherRoot = Workspace.get(byName: "b").rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
        }
        assertEquals(focusedRoot.layout, .tiles)
        assertEquals(otherRoot.layout, .tiles)

        await parseCommand("layout --root --workspace b v_accordion").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(otherRoot.layout, .accordion)
        assertEquals(otherRoot.orientation, .v)
        assertEquals(focusedRoot.layout, .tiles) // Focused workspace must be untouched
    }

    func testRoot_toggleBetween_skipsMatching() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            }
            TestWindow.new(id: 2, parent: $0)
        }
        assertEquals(root.layoutDescription, .h_tiles([
            .v_tiles([.window(1)]),
            .window(2),
        ]))

        await parseCommand("layout --root h_tiles h_accordion").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layout, .accordion)
        assertEquals(root.orientation, .h)
        assertEquals(root.layoutDescription, .h_accordion([
            .v_tiles([.window(1)]),
            .window(2),
        ]))
    }

    func testRoot_alreadyMatches_fails() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))

        let result = await parseCommand("layout --root h_tiles").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))
    }
}
