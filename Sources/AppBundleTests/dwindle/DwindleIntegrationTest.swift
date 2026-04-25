@testable import AppBundle
import AppKit
import Common
import XCTest

/// End-to-end integration tests for dwindle: focus, move, flatten, layout-CLI
/// scenarios run against a workspace whose root container is `.dwindle`.
@MainActor
final class DwindleIntegrationTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        config.dwindle = DwindleConfig()
    }

    /// `flatten-workspace-tree` rebinds all leaves directly under the root via
    /// `bind()` (not the new-window path), so dwindle's insertion algorithm is
    /// bypassed and the result is a flat row regardless of the root layout.
    /// Subsequent new windows trigger dwindle wrapping again.
    func testFlattenWorkspaceTree_underDwindleRoot_producesFlatRow() async throws {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        // Build a deep dwindle tree manually: root → [W1, split{W2, split{W3, W4}}]
        let w1 = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let split1 = TilingContainer(
            parent: workspace.rootTilingContainer,
            adaptiveWeight: 1,
            .v,
            .dwindle,
            index: INDEX_BIND_LAST,
        )
        let w2 = TestWindow.new(id: 2, parent: split1)
        let split2 = TilingContainer(
            parent: split1,
            adaptiveWeight: 1,
            .h,
            .dwindle,
            index: INDEX_BIND_LAST,
        )
        let w3 = TestWindow.new(id: 3, parent: split2)
        let w4 = TestWindow.new(id: 4, parent: split2)
        _ = (w1, w2, w3, w4)
        XCTAssertTrue(workspace.focusWorkspace())

        try await FlattenWorkspaceTreeCommand(args: FlattenWorkspaceTreeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        // After flatten, all four windows are direct children of root and the
        // intermediate split containers are gone.
        assertEquals(workspace.rootTilingContainer.children.count, 4)
        for child in workspace.rootTilingContainer.children {
            XCTAssertTrue(child is Window)
        }
        // Root is still dwindle.
        assertEquals(workspace.rootTilingContainer.layout, .dwindle)
    }

    /// `aerospace layout dwindle` flips a tiles container's layout. CLI parity
    /// test for the new variant.
    func testLayoutCommand_dwindle_changesParentLayout() async throws {
        let workspace = Workspace.get(byName: name)
        let target = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        XCTAssertTrue(target.focusWindow())

        // Default root layout is `.tiles`. Switch to dwindle via CLI.
        _ = try await parseCommand("layout dwindle").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(workspace.rootTilingContainer.layout, .dwindle)
    }

    /// `aerospace layout h_dwindle` sets both layout and orientation.
    func testLayoutCommand_h_dwindle_setsLayoutAndOrientation() async throws {
        let workspace = Workspace.get(byName: name)
        // Set up a vertical-oriented tiles root.
        let target = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        XCTAssertTrue(target.focusWindow())

        _ = try await parseCommand("layout h_dwindle").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(workspace.rootTilingContainer.layout, .dwindle)
        assertEquals(workspace.rootTilingContainer.orientation, .h)
    }

    /// `default-root-container-layout = 'dwindle'` is accepted.
    func testParse_defaultRootContainerLayoutDwindle() {
        let (parsed, errors) = parseConfig(
            """
            default-root-container-layout = 'dwindle'
            """,
        )
        assertEquals(errors, [])
        assertEquals(parsed.defaultRootContainerLayout, .dwindle)
    }

    /// Existing workspaces are not retroactively converted on config reload.
    /// The conservative-config precedent (WorkspaceEx.swift creates rootTilingContainer
    /// with the default at workspace-creation time only) is preserved.
    func testReload_doesNotRetroactivelyConvertExistingWorkspaces() {
        let workspace = Workspace.get(byName: name)
        // Default is `.tiles`.
        assertEquals(workspace.rootTilingContainer.layout, .tiles)

        // Simulate a config reload that flips the default to dwindle.
        let oldConfig = config
        defer { config = oldConfig }
        let (newConfig, errors) = parseConfig(
            """
            default-root-container-layout = 'dwindle'
            """,
        )
        assertEquals(errors, [])
        config = newConfig

        // Existing workspace's root is unchanged.
        assertEquals(workspace.rootTilingContainer.layout, .tiles)
    }

    /// `[dwindle].no-gaps-when-only = true`: the single window in a dwindle
    /// workspace fills the full visible rect, ignoring outer gaps.
    func testNoGapsWhenOnly_singleWindowFillsMonitor() async throws {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        config.dwindle.noGapsWhenOnly = true
        // Set non-zero outer gaps so we can distinguish padded vs. raw rects.
        config.gaps.outer.left = .constant(20)
        config.gaps.outer.right = .constant(20)
        config.gaps.outer.top = .constant(20)
        config.gaps.outer.bottom = .constant(20)

        let win = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        try await workspace.layoutWorkspace()

        // Window's physical rect should match the monitor's visibleRect (no gaps).
        let monitorRect = workspace.workspaceMonitor.visibleRect
        let windowRect = win.lastAppliedLayoutPhysicalRect
        XCTAssertNotNil(windowRect)
        assertEquals(windowRect?.topLeftX, monitorRect.topLeftX)
        assertEquals(windowRect?.topLeftY, monitorRect.topLeftY)
        assertEquals(windowRect?.width, monitorRect.width)
    }

    /// `[dwindle].no-gaps-when-only = true`: a SECOND window restores the gaps
    /// — the option only suppresses gaps when there's exactly one window.
    func testNoGapsWhenOnly_secondWindowRestoresGaps() async throws {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .dwindle
        config.dwindle.noGapsWhenOnly = true
        config.gaps.outer.left = .constant(20)
        config.gaps.outer.right = .constant(20)
        config.gaps.outer.top = .constant(20)
        config.gaps.outer.bottom = .constant(20)

        let w1 = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let w2 = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        _ = (w1, w2)
        try await workspace.layoutWorkspace()

        // With 2 windows, outer gaps apply: workspace-padded rect != visibleRect.
        let monitorRect = workspace.workspaceMonitor.visibleRect
        let paddedRect = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        XCTAssertNotEqual(monitorRect.width, paddedRect.width) // sanity: gaps present
        // First window starts at the padded rect's top-left, not the monitor's.
        let w1Rect = w1.lastAppliedLayoutPhysicalRect
        assertEquals(w1Rect?.topLeftX, paddedRect.topLeftX)
        assertEquals(w1Rect?.topLeftY, paddedRect.topLeftY)
    }

    /// `no-gaps-when-only` is scoped to dwindle workspaces — a single-window
    /// tiles workspace still gets gaps even with the flag set.
    func testNoGapsWhenOnly_doesNotApplyToTilesWorkspace() async throws {
        let workspace = Workspace.get(byName: name)
        // Default root is .tiles.
        config.dwindle.noGapsWhenOnly = true
        config.gaps.outer.left = .constant(20)
        config.gaps.outer.right = .constant(20)
        config.gaps.outer.top = .constant(20)
        config.gaps.outer.bottom = .constant(20)

        let win = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        try await workspace.layoutWorkspace()

        let paddedRect = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        let windowRect = win.lastAppliedLayoutPhysicalRect
        // Window is at the padded rect's top-left (gaps applied), not at (0,0).
        assertEquals(windowRect?.topLeftX, paddedRect.topLeftX)
        assertEquals(windowRect?.topLeftY, paddedRect.topLeftY)
    }
}
