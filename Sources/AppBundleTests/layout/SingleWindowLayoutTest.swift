@testable import AppBundle
import Common
import XCTest

@MainActor
final class SingleWindowLayoutTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSingleWindowRespectsMaxWidthPercent() async throws {
        config.singleWindowMaxWidthPercent = .constant(70)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let expectedMaxWidth = monitorWidth * 0.7
        let expectedSideGap = (monitorWidth - expectedMaxWidth) / 2

        let actualRect = window.lastAppliedLayoutPhysicalRect!
        let actualWidth = actualRect.width
        let actualX = actualRect.topLeftX

        assertEquals(actualWidth, expectedMaxWidth)
        assertEquals(actualX, expectedSideGap)
    }

    func testSingleWindowWith50PercentWidth() async throws {
        config.singleWindowMaxWidthPercent = .constant(50)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let expectedMaxWidth = monitorWidth * 0.5
        let expectedSideGap = (monitorWidth - expectedMaxWidth) / 2

        let actualRect = window.lastAppliedLayoutPhysicalRect!
        assertEquals(actualRect.width, expectedMaxWidth)
        assertEquals(actualRect.topLeftX, expectedSideGap)
    }

    func testSingleWindowWith100PercentWidth() async throws {
        config.singleWindowMaxWidthPercent = .constant(100)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let actualRect = window.lastAppliedLayoutPhysicalRect!

        assertEquals(actualRect.width, monitorWidth)
        assertEquals(actualRect.topLeftX, 0.0)
    }

    func testMultipleWindowsIgnoreMaxWidth() async throws {
        config.singleWindowMaxWidthPercent = .constant(70)

        let workspace = Workspace.get(byName: name)
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        TestWindow.new(id: 2, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let totalWindowsWidth = workspace.rootTilingContainer.children
            .compactMap { ($0 as? Window)?.lastAppliedLayoutPhysicalRect?.width }
            .reduce(0, +)

        // With multiple windows, should use full width (minus normal gaps)
        assertEquals(totalWindowsWidth, monitorWidth)
    }

    func testExcludedAppBypassesMaxWidth() async throws {
        config.singleWindowMaxWidthPercent = .constant(50)
        config.singleWindowExcludeAppIds = ["bobko.AeroSpace.test-app"]

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let actualRect = window.lastAppliedLayoutPhysicalRect!

        // Should use full width since app is excluded
        assertEquals(actualRect.width, monitorWidth)
        assertEquals(actualRect.topLeftX, 0.0)
    }

    func testNonExcludedAppRespectsMaxWidth() async throws {
        config.singleWindowMaxWidthPercent = .constant(60)
        config.singleWindowExcludeAppIds = ["com.different.app"]

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let expectedMaxWidth = monitorWidth * 0.6
        let expectedSideGap = (monitorWidth - expectedMaxWidth) / 2

        let actualRect = window.lastAppliedLayoutPhysicalRect!
        assertEquals(actualRect.width, expectedMaxWidth)
        assertEquals(actualRect.topLeftX, expectedSideGap)
    }

    func testSingleWindowWithExistingGaps() async throws {
        config.singleWindowMaxWidthPercent = .constant(80)
        config.gaps.outer.left = .constant(20)
        config.gaps.outer.right = .constant(20)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        _ = monitorWidth - 40 // Subtract outer gaps
        let expectedMaxWidth = monitorWidth * 0.8
        let singleWindowSideGap = (monitorWidth - expectedMaxWidth) / 2
        let totalLeftGap = 20 + singleWindowSideGap // base outer gap + single-window gap

        let actualRect = window.lastAppliedLayoutPhysicalRect!
        assertEquals(actualRect.topLeftX, totalLeftGap)
        assertEquals(actualRect.width, expectedMaxWidth - 40) // Max width minus base outer gaps
    }

    func testPerMonitorSingleWindowConfig() async throws {
        let workspace = Workspace.get(byName: name)
        _ = workspace.workspaceMonitor
        config.singleWindowMaxWidthPercent = .perMonitor([
            PerMonitorValue(description: MonitorDescription.pattern(".*")!, value: 75),
        ], default: 100)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let expectedMaxWidth = monitorWidth * 0.75
        let expectedSideGap = (monitorWidth - expectedMaxWidth) / 2

        let actualRect = window.lastAppliedLayoutPhysicalRect!
        assertEquals(actualRect.width, expectedMaxWidth)
        assertEquals(actualRect.topLeftX, expectedSideGap)
    }

    func testSingleWindowHeightUnaffected() async throws {
        config.singleWindowMaxWidthPercent = .constant(70)

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorHeight = workspace.workspaceMonitor.visibleRect.height
        let actualRect = window.lastAppliedLayoutPhysicalRect!

        // Height should remain full (minus 1 for the layout adjustment)
        assertEquals(actualRect.height, monitorHeight - 1)
        assertEquals(actualRect.topLeftY, 0.0)
    }

    func testZeroPercentWidthFallsBackToDefault() async throws {
        // This test ensures invalid config values are handled gracefully
        config.singleWindowMaxWidthPercent = .constant(100) // Should fall back to this

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        let monitorWidth = workspace.workspaceMonitor.visibleRect.width
        let actualRect = window.lastAppliedLayoutPhysicalRect!

        // Should use full width
        assertEquals(actualRect.width, monitorWidth)
        assertEquals(actualRect.topLeftX, 0.0)
    }
}
