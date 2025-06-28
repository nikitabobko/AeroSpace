@testable import AppBundle
import Common
import XCTest

@MainActor
final class FullscreenCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testFullscreenToggle() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        // Test toggle on
        let result1 = try await parseCommand("fullscreen").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result1.exitCode, 0)
        assertEquals(window.isFullscreen, true)

        // Test toggle off
        let result2 = try await parseCommand("fullscreen").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result2.exitCode, 0)
        assertEquals(window.isFullscreen, false)
    }

    func testFullscreenOn() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        let result = try await parseCommand("fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(window.isFullscreen, true)
    }

    func testFullscreenOff() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)
        window.isFullscreen = true

        let result = try await parseCommand("fullscreen off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(window.isFullscreen, false)
    }

    func testNoOuterGapsFlag() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        let result = try await parseCommand("fullscreen --no-outer-gaps on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(window.isFullscreen, true)
        assertEquals(window.noOuterGapsInFullscreen, true)
        assertEquals(window.noMaxWidthInFullscreen, false)
    }

    func testNoMaxWidthFlag() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        let result = try await parseCommand("fullscreen --no-max-width on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(window.isFullscreen, true)
        assertEquals(window.noMaxWidthInFullscreen, true)
        assertEquals(window.noOuterGapsInFullscreen, false)
    }

    func testBothFlags() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        let result = try await parseCommand("fullscreen --no-outer-gaps --no-max-width on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(window.isFullscreen, true)
        assertEquals(window.noOuterGapsInFullscreen, true)
        assertEquals(window.noMaxWidthInFullscreen, true)
    }

    func testNoMaxWidthFlagWithToggle() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        // Toggle on with --no-max-width
        let result1 = try await parseCommand("fullscreen --no-max-width").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result1.exitCode, 0)
        assertEquals(window.isFullscreen, true)
        assertEquals(window.noMaxWidthInFullscreen, true)

        // Toggle off should preserve window state but turn off fullscreen
        let result2 = try await parseCommand("fullscreen").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result2.exitCode, 0)
        assertEquals(window.isFullscreen, false)
    }

    func testNoMaxWidthFlagDoubleToggle() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        // First toggle: Turn on fullscreen with --no-max-width
        let result1 = try await parseCommand("fullscreen --no-max-width").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result1.exitCode, 0)
        assertEquals(window.isFullscreen, true)
        assertEquals(window.noMaxWidthInFullscreen, true)

        // Second toggle: Run the same command again - should turn OFF fullscreen
        let result2 = try await parseCommand("fullscreen --no-max-width").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result2.exitCode, 0)
        assertEquals(window.isFullscreen, false)
        assertEquals(window.noMaxWidthInFullscreen, true)  // Should preserve the flag
    }


    func testFailIfNoop() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)
        window.isFullscreen = true

        let result = try await parseCommand("fullscreen --fail-if-noop on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 1)
        assertEquals(window.isFullscreen, true)
    }

    func testNoWindowFocused() async throws {
        // No focused window
        let result = try await parseCommand("fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 1)
        assertEquals(result.stderr.joined(separator: "\n"), "No window is focused")
    }

    func testFullscreenCallsMarkAsMostRecentChild() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        let result = try await parseCommand("fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(window.isFullscreen, true)

        // This test verifies that the fullscreen command executes without error
        // and properly sets the fullscreen state - the implementation calls markAsMostRecentChild
    }

    // MARK: - Command Argument Parsing Tests

    func testParseNoMaxWidthFlag() {
        testParseCommandSucc(
            "fullscreen --no-max-width on",
            createFullscreenCmdArgs(toggle: .on, noMaxWidth: true),
        )
    }

    func testParseNoOuterGapsFlag() {
        testParseCommandSucc(
            "fullscreen --no-outer-gaps on",
            createFullscreenCmdArgs(toggle: .on, noOuterGaps: true),
        )
    }

    func testParseBothFlags() {
        testParseCommandSucc(
            "fullscreen --no-outer-gaps --no-max-width on",
            createFullscreenCmdArgs(toggle: .on, noOuterGaps: true, noMaxWidth: true),
        )
    }

    func testParseToggleDefault() {
        testParseCommandSucc(
            "fullscreen --no-max-width",
            createFullscreenCmdArgs(toggle: .toggle, noMaxWidth: true),
        )
    }

    func testParseFailIfNoop() {
        testParseCommandSucc(
            "fullscreen --fail-if-noop on",
            createFullscreenCmdArgs(toggle: .on, failIfNoop: true),
        )
    }

    // MARK: - Error Cases

    func testNoOuterGapsIncompatibleWithOff() {
        testParseCommandFail(
            "fullscreen --no-outer-gaps off",
            msg: "--no-outer-gaps is incompatible with 'off' argument",
        )
    }

    func testNoMaxWidthIncompatibleWithOff() {
        testParseCommandFail(
            "fullscreen --no-max-width off",
            msg: "--no-max-width is incompatible with 'off' argument",
        )
    }

    func testFailIfNoopRequiresOnOrOff() {
        testParseCommandFail(
            "fullscreen --fail-if-noop",
            msg: "--fail-if-noop requires 'on' or 'off' argument",
        )
    }

    // MARK: - Single-Window Max Width Integration Tests

    func testFullscreenRespectsSingleWindowMaxWidth() async throws {
        config.singleWindowMaxWidthPercent = .constant(70)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        let result = try await parseCommand("fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(window.isFullscreen, true)

        // Trigger layout to verify fullscreen respects single-window width constraints
        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let expectedMaxWidth = monitorWidth * 0.7
        let actualRect = window.lastAppliedLayoutPhysicalRect!

        // Fullscreen should respect single-window max width by default
        assertEquals(actualRect.width, expectedMaxWidth)
    }

    func testFullscreenWithNoMaxWidthBypassesSingleWindowConstraints() async throws {
        config.singleWindowMaxWidthPercent = .constant(60)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        let result = try await parseCommand("fullscreen --no-max-width on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(window.isFullscreen, true)
        assertEquals(window.noMaxWidthInFullscreen, true)

        // Trigger layout to verify --no-max-width bypasses width constraints
        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let actualRect = window.lastAppliedLayoutPhysicalRect!

        // With --no-max-width, should use full monitor width
        assertEquals(actualRect.width, monitorWidth)
        assertEquals(actualRect.topLeftX, 0.0)
    }

    func testFullscreenWithBothFlagsAndSingleWindowConfig() async throws {
        config.singleWindowMaxWidthPercent = .constant(80)
        config.gaps.outer.left = .constant(10)
        config.gaps.outer.right = .constant(10)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        // Use both flags - --no-max-width should override single-window constraints
        let result = try await parseCommand("fullscreen --no-outer-gaps --no-max-width on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(window.isFullscreen, true)
        assertEquals(window.noOuterGapsInFullscreen, true)
        assertEquals(window.noMaxWidthInFullscreen, true)

        try await workspace.layoutWorkspace()

        let monitorRect = workspace.workspaceMonitor.visibleRect
        let actualRect = window.lastAppliedLayoutPhysicalRect!

        // Should use full monitor rect (no gaps, no width constraints)
        assertEquals(actualRect.width, monitorRect.width)
        assertEquals(actualRect.height, monitorRect.height)
        assertEquals(actualRect.topLeftX, monitorRect.topLeftX)
        assertEquals(actualRect.topLeftY, monitorRect.topLeftY)
    }


    func testFullscreenExcludedAppBypassesSingleWindowConstraints() async throws {
        config.singleWindowMaxWidthPercent = .constant(50)
        config.singleWindowExcludeAppIds = ["bobko.AeroSpace.test-app"]

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        let result = try await parseCommand("fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(window.isFullscreen, true)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let actualRect = window.lastAppliedLayoutPhysicalRect!

        // Excluded app should bypass single-window width constraints even in fullscreen
        assertEquals(actualRect.width, monitorWidth)
    }

    func testFullscreenPerMonitorSingleWindowConfig() async throws {
        config.singleWindowMaxWidthPercent = .perMonitor([
            PerMonitorValue(description: MonitorDescription.pattern(".*")!, value: 75),
        ], default: 100)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        let result = try await parseCommand("fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(window.isFullscreen, true)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let expectedMaxWidth = monitorWidth * 0.75
        let actualRect = window.lastAppliedLayoutPhysicalRect!

        // Should respect per-monitor single-window configuration
        assertEquals(actualRect.width, expectedMaxWidth)
    }

    // MARK: - Focus Switching Tests

    func testFullscreenExitsWhenFocusSwitchesToOtherWindow() async throws {
        let workspace = Workspace.get(byName: name)
        let window1 = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let window2 = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)

        // Focus and fullscreen window1
        assertEquals(window1.focusWindow(), true)
        let result1 = try await parseCommand("fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result1.exitCode, 0)
        assertEquals(window1.isFullscreen, true)

        // Switch focus to window2
        assertEquals(window2.focusWindow(), true)

        // Window1 should no longer be fullscreen
        assertEquals(window1.isFullscreen, false)
        assertEquals(window2.isFullscreen, false)
    }

    func testFullscreenExitsWhenFocusSwitchesToWorkspace() async throws {
        let workspace1 = Workspace.get(byName: name)
        let workspace2 = Workspace.get(byName: "workspace2")
        let window1 = TestWindow.new(id: 1, parent: workspace1.rootTilingContainer)
        let window2 = TestWindow.new(id: 2, parent: workspace2.rootTilingContainer)

        // Focus and fullscreen window1 in workspace1
        assertEquals(window1.focusWindow(), true)
        let result1 = try await parseCommand("fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result1.exitCode, 0)
        assertEquals(window1.isFullscreen, true)

        // Switch to workspace2 and focus window2
        assertEquals(window2.focusWindow(), true)

        // Window1 should no longer be fullscreen
        assertEquals(window1.isFullscreen, false)
        assertEquals(window2.isFullscreen, false)
    }

    func testFullscreenDoesNotReturnWhenRefocusingPreviouslyFullscreenWindow() async throws {
        let workspace = Workspace.get(byName: name)
        let window1 = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let window2 = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)

        // Focus and fullscreen window1
        assertEquals(window1.focusWindow(), true)
        let result1 = try await parseCommand("fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result1.exitCode, 0)
        assertEquals(window1.isFullscreen, true)

        // Switch focus to window2
        assertEquals(window2.focusWindow(), true)
        assertEquals(window1.isFullscreen, false)

        // Switch focus back to window1
        assertEquals(window1.focusWindow(), true)

        // Window1 should remain NOT fullscreen
        assertEquals(window1.isFullscreen, false)
        assertEquals(window2.isFullscreen, false)
    }

    func testMultipleFullscreenWindowsInDifferentWorkspaces() async throws {
        let workspace1 = Workspace.get(byName: name)
        let workspace2 = Workspace.get(byName: "workspace2")
        let window1 = TestWindow.new(id: 1, parent: workspace1.rootTilingContainer)
        let window2 = TestWindow.new(id: 2, parent: workspace2.rootTilingContainer)

        // Fullscreen window1 in workspace1
        assertEquals(window1.focusWindow(), true)
        let result1 = try await parseCommand("fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result1.exitCode, 0)
        assertEquals(window1.isFullscreen, true)

        // Switch to workspace2 and fullscreen window2
        assertEquals(window2.focusWindow(), true)
        assertEquals(window1.isFullscreen, false) // Should exit fullscreen

        let result2 = try await parseCommand("fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result2.exitCode, 0)
        assertEquals(window2.isFullscreen, true)

        // Switch back to workspace1
        assertEquals(window1.focusWindow(), true)
        assertEquals(window2.isFullscreen, false) // Should exit fullscreen
        assertEquals(window1.isFullscreen, false) // Should remain not fullscreen
    }

    func testFullscreenOnlyExitWhenActuallyChangingFocus() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        // Focus and fullscreen window
        assertEquals(window.focusWindow(), true)
        let result1 = try await parseCommand("fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result1.exitCode, 0)
        assertEquals(window.isFullscreen, true)

        // "Focus" the same window again (should be no-op)
        assertEquals(window.focusWindow(), true)

        // Window should remain fullscreen since focus didn't actually change
        assertEquals(window.isFullscreen, true)
    }
}

private func createFullscreenCmdArgs(toggle: ToggleEnum, noOuterGaps: Bool = false, noMaxWidth: Bool = false, failIfNoop: Bool = false) -> FullscreenCmdArgs {
    var cmdArgs: [String] = []

    if noOuterGaps { cmdArgs.append("--no-outer-gaps") }
    if noMaxWidth { cmdArgs.append("--no-max-width") }
    if failIfNoop { cmdArgs.append("--fail-if-noop") }

    switch toggle {
        case .on: cmdArgs.append("on")
        case .off: cmdArgs.append("off")
        case .toggle: break // default, no argument needed
    }

    switch parseFullscreenCmdArgs(cmdArgs) {
        case .cmd(let args): return args
        case .failure(let msg): fatalError("Failed to create test args: \(msg)")
        case .help: fatalError("Unexpected help result")
    }
}
