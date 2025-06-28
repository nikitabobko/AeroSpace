@testable import AppBundle
import Common
import XCTest

@MainActor
final class MultiMonitorSingleWindowTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testPerMonitorSingleWindowConfigurationConstant() async throws {
        config.singleWindowMaxWidthPercent = .perMonitor([
            PerMonitorValue(description: MonitorDescription.pattern(".*")!, value: 80),
        ], default: 90)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let expectedMaxWidth = monitorWidth * 0.8 // Should use per-monitor value
        let expectedSideGap = (monitorWidth - expectedMaxWidth) / 2

        let actualRect = window.lastAppliedLayoutPhysicalRect!
        assertEquals(actualRect.width, expectedMaxWidth)
        assertEquals(actualRect.topLeftX, expectedSideGap)
    }

    func testPerMonitorSingleWindowConfigurationFallbackToDefault() async throws {
        // Create per-monitor config that won't match current monitor
        config.singleWindowMaxWidthPercent = .perMonitor([
            PerMonitorValue(description: MonitorDescription.pattern("NonExistentMonitor")!, value: 60),
        ], default: 75)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let expectedMaxWidth = monitorWidth * 0.75 // Should use default value
        let expectedSideGap = (monitorWidth - expectedMaxWidth) / 2

        let actualRect = window.lastAppliedLayoutPhysicalRect!
        assertEquals(actualRect.width, expectedMaxWidth)
        assertEquals(actualRect.topLeftX, expectedSideGap)
    }

    func testMultiplePerMonitorPatterns() async throws {
        // Test with multiple separate patterns (now requires separate entries)
        config.singleWindowMaxWidthPercent = .perMonitor([
            PerMonitorValue(description: MonitorDescription.pattern(".*")!, value: 70),
            PerMonitorValue(description: MonitorDescription.pattern("Built-in.*")!, value: 80),
        ], default: 95)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let expectedMaxWidth = monitorWidth * 0.7 // Should use first matching pattern
        let expectedSideGap = (monitorWidth - expectedMaxWidth) / 2

        let actualRect = window.lastAppliedLayoutPhysicalRect!
        assertEquals(actualRect.width, expectedMaxWidth)
        assertEquals(actualRect.topLeftX, expectedSideGap)
    }

    func testPerMonitorConfigWithExcludedApp() async throws {
        config.singleWindowMaxWidthPercent = .perMonitor([
            PerMonitorValue(description: MonitorDescription.pattern(".*")!, value: 50),
        ], default: 100)
        config.singleWindowExcludeAppIds = ["bobko.AeroSpace.test-app"]

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let actualRect = window.lastAppliedLayoutPhysicalRect!

        // App is excluded, should use full width regardless of per-monitor config
        assertEquals(actualRect.width, monitorWidth)
        assertEquals(actualRect.topLeftX, 0.0)
    }

    func testPerMonitorConfigWithMultipleWindows() async throws {
        config.singleWindowMaxWidthPercent = .perMonitor([
            PerMonitorValue(description: MonitorDescription.pattern(".*")!, value: 60),
        ], default: 100)

        let workspace = Workspace.get(byName: name)
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        TestWindow.new(id: 2, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let totalWindowsWidth = workspace.rootTilingContainer.children
            .compactMap { ($0 as? Window)?.lastAppliedLayoutPhysicalRect?.width }
            .reduce(0, +)

        // Multiple windows should ignore single-window config and use full width
        assertEquals(totalWindowsWidth, monitorWidth)
    }

    func testPerMonitorConfigWithGaps() async throws {
        config.singleWindowMaxWidthPercent = .perMonitor([
            PerMonitorValue(description: MonitorDescription.pattern(".*")!, value: 80),
        ], default: 100)
        config.gaps.outer.left = .constant(20)
        config.gaps.outer.right = .constant(30)
        config.gaps.outer.top = .constant(15)
        config.gaps.outer.bottom = .constant(25)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let monitorHeight = workspace.workspaceMonitor.visibleRect.height
        let expectedMaxWidth = monitorWidth * 0.8
        let singleWindowSideGap = (monitorWidth - expectedMaxWidth) / 2

        let actualRect = window.lastAppliedLayoutPhysicalRect!

        // Width should account for both base gaps and single-window gaps
        assertEquals(actualRect.width, expectedMaxWidth - 50) // Max width minus left/right gaps
        assertEquals(actualRect.topLeftX, 20 + singleWindowSideGap) // Base left gap + single-window gap
        assertEquals(actualRect.height, monitorHeight - 40 - 1) // Height minus top/bottom gaps and layout adjustment
        assertEquals(actualRect.topLeftY, 15.0) // Top gap
    }

    func testPerMonitorConfigInFullscreen() async throws {
        config.singleWindowMaxWidthPercent = .perMonitor([
            PerMonitorValue(description: MonitorDescription.pattern(".*")!, value: 65),
        ], default: 100)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        // Enable fullscreen
        let result = try await parseCommand("fullscreen on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(window.isFullscreen, true)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let expectedMaxWidth = monitorWidth * 0.65
        let actualRect = window.lastAppliedLayoutPhysicalRect!

        // Fullscreen should respect per-monitor single-window configuration
        assertEquals(actualRect.width, expectedMaxWidth)
    }

    func testPerMonitorConfigInFullscreenWithNoMaxWidth() async throws {
        config.singleWindowMaxWidthPercent = .perMonitor([
            PerMonitorValue(description: MonitorDescription.pattern(".*")!, value: 40),
        ], default: 100)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        // Enable fullscreen with --no-max-width flag
        let result = try await parseCommand("fullscreen --no-max-width on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(window.isFullscreen, true)
        assertEquals(window.noMaxWidthInFullscreen, true)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let actualRect = window.lastAppliedLayoutPhysicalRect!

        // --no-max-width should override per-monitor single-window configuration
        assertEquals(actualRect.width, monitorWidth)
        assertEquals(actualRect.topLeftX, 0.0)
    }

    func testPerMonitorGapsConfiguration() async throws {
        // Test per-monitor gaps alongside single-window config
        config.singleWindowMaxWidthPercent = .constant(90)
        config.gaps.outer.left = .perMonitor([
            PerMonitorValue(description: MonitorDescription.pattern(".*")!, value: 25),
        ], default: 10)
        config.gaps.outer.right = .perMonitor([
            PerMonitorValue(description: MonitorDescription.pattern(".*")!, value: 35),
        ], default: 15)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let expectedMaxWidth = monitorWidth * 0.9
        let singleWindowSideGap = (monitorWidth - expectedMaxWidth) / 2

        let actualRect = window.lastAppliedLayoutPhysicalRect!

        // Should combine per-monitor gaps with single-window gaps
        assertEquals(actualRect.topLeftX, 25 + singleWindowSideGap) // Per-monitor left gap + single-window gap
        assertEquals(actualRect.width, expectedMaxWidth - 60) // Max width minus per-monitor left/right gaps
    }
}
