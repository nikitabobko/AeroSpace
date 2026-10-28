@testable import AppBundle
import Common
import XCTest

/// The focused workspace must stay visible after monitors are added, removed or moved
@MainActor
final class DisplayReconcileTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    // Leave no test monitors or focus behind for other test classes
    override func tearDown() async throws {
        setTestMonitors([])
        gcMonitors()
        setTestMonitors(nil)
        resetFocusForTests()
    }

    func testFocusedForceAssignedWorkspaceStaysVisibleWhenMonitorDisconnects() {
        seedOpenThreeMonitors(forceAssignNumerics: true)
        assertTrue(Workspace.get(byName: "2").focusWorkspace())
        applyClosedTwoMonitors()
        gcMonitors()

        assertEquals(focus.workspace.name, "2")
        assertEquals(closedRight().activeWorkspace.name, "2")
        assertFalse(Workspace.get(byName: "R").isVisible)
        assertReconcileInvariants()
        gcMonitors()
        assertEquals(closedRight().activeWorkspace.name, "2")
        assertFalse(Workspace.get(byName: "R").isVisible)
        assertReconcileInvariants()
    }

    func testFocusedWorkspaceThatStaysVisibleIsNotMoved() {
        seedOpenThreeMonitors(forceAssignNumerics: false)
        assertTrue(Workspace.get(byName: "2").focusWorkspace())
        applyClosedTwoMonitors()
        gcMonitors()

        assertEquals(focus.workspace.name, "2")
        assertEquals(closedLeft().activeWorkspace.name, "2")
        assertEquals(closedRight().activeWorkspace.name, "R")
        assertReconcileInvariants()
    }

    func testFocusedWorkspaceWinsWhenTwoWorkspacesMapToOneMonitor() {
        seedOpenThreeMonitors(forceAssignNumerics: false)
        assertTrue(Workspace.get(byName: "1").focusWorkspace())
        applyClosedTwoMonitors()
        gcMonitors()

        assertEquals(focus.workspace.name, "1")
        assertEquals(closedLeft().activeWorkspace.name, "1")
        assertFalse(Workspace.get(byName: "2").isVisible)
        assertEquals(closedRight().activeWorkspace.name, "R")
        assertTrue(Workspace.get(byName: "R").isVisible)
        assertReconcileInvariants()
    }

    func testFocusInitializationAfterAllMonitorsDisconnect() {
        seedOpenThreeMonitors(forceAssignNumerics: true)
        setTestMonitors([])
        gcMonitors()
        resetFocusForTests()
        assertNil(initializedFocusWorkspaceName)
        setTestMonitors([closedLeft()])
        gcMonitors()
        assertNil(initializedFocusWorkspaceName) // Rearranging must not initialize the focus

        // Initializing the focus rearranges the monitors once and doesn't recurse
        setTestMonitors([])
        gcMonitors()
        setTestMonitors([closedLeft()])
        let workspace = focus.workspace
        assertNotNil(initializedFocusWorkspaceName)
        assertTrue(workspace.isVisible)
        assertEquals(closedLeft().activeWorkspace.name, workspace.name)
        assertReconcileInvariants()
    }

    func testFocusedWorkspaceStaysVisibleWhenMonitorsMove() {
        config.persistentWorkspaces = ["1", "R"]
        setTestMonitors([closedLeft(), closedRight()])
        gcMonitors()
        check(closedLeft().setActiveWorkspace(Workspace.get(byName: "1")))
        check(closedRight().setActiveWorkspace(Workspace.get(byName: "R")))
        assertTrue(Workspace.get(byName: "1").focusWorkspace())

        let shiftedLeft = testMonitor(
            name: "Left",
            id: 1,
            topLeftX: 10,
            topLeftY: 10,
            width: 1920,
            height: 1080,
            isMain: true,
        )
        let shiftedRight = testMonitor(
            name: "Right",
            id: 2,
            topLeftX: 1930,
            topLeftY: 10,
            width: 1920,
            height: 1080,
            isMain: false,
        )
        setTestMonitors([shiftedLeft, shiftedRight])
        gcMonitors()
        assertEquals(closedLeft().activeWorkspace.name, "1")

        assertEquals(shiftedLeft.activeWorkspace.name, "1")
        assertTrue(Workspace.get(byName: "1").isVisible)
        assertEquals(shiftedRight.activeWorkspace.name, "R")
        assertReconcileInvariants()
    }

    func testNoMonitorsLeavesNoVisibleWorkspaces() {
        seedOpenThreeMonitors(forceAssignNumerics: true)
        assertTrue(Workspace.get(byName: "2").focusWorkspace())
        setTestMonitors([])
        gcMonitors()
        assertEquals(initializedFocusWorkspaceName, "2")
        assertEquals(focus.workspace.name, "2")
        assertFalse(Workspace.get(byName: "2").isVisible)
        assertEquals(visibleSnapshot().count, 0)
    }
}

private struct TestMonitor: MonitorInfo {
    let monitorAppKitNsScreenScreensId: Int
    let name: String
    let rect: Rect
    let visibleRect: Rect
    let isMain: Bool
    var width: CGFloat { rect.width }
    var height: CGFloat { rect.height }
}

@MainActor
private func setTestMonitors(_ monitors: [MonitorInfo]?) {
    unsafe monitorInfosForTests = monitors
}

@MainActor
private func testMonitor(
    name: String,
    id: Int,
    topLeftX: CGFloat,
    topLeftY: CGFloat,
    width: CGFloat,
    height: CGFloat,
    isMain: Bool,
) -> MonitorInfo {
    let rect = Rect(topLeftX: topLeftX, topLeftY: topLeftY, width: width, height: height)
    return TestMonitor(
        monitorAppKitNsScreenScreensId: id,
        name: name,
        rect: rect,
        visibleRect: rect,
        isMain: isMain,
    )
}

@MainActor
private func openLeft() -> MonitorInfo {
    testMonitor(name: "Left", id: 1, topLeftX: -1920, topLeftY: -1080, width: 1920, height: 1080, isMain: false)
}

@MainActor
private func openLaptop() -> MonitorInfo {
    testMonitor(name: "Laptop", id: 2, topLeftX: 0, topLeftY: 0, width: 1728, height: 1117, isMain: true)
}

@MainActor
private func openRight() -> MonitorInfo {
    testMonitor(name: "Right", id: 3, topLeftX: 1728, topLeftY: -1080, width: 1920, height: 1080, isMain: false)
}

@MainActor
private func closedLeft() -> MonitorInfo {
    testMonitor(name: "Left", id: 1, topLeftX: 0, topLeftY: 0, width: 1920, height: 1080, isMain: true)
}

@MainActor
private func closedRight() -> MonitorInfo {
    testMonitor(name: "Right", id: 2, topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080, isMain: false)
}

@MainActor
private func seedOpenThreeMonitors(forceAssignNumerics: Bool) {
    config.persistentWorkspaces = ["1", "2", "R"]
    if forceAssignNumerics {
        config.workspaceToMonitorForceAssignment = [
            "1": [.sequenceNumber(1)],
            "2": [.sequenceNumber(2)],
        ]
    }
    setTestMonitors([openLeft(), openLaptop(), openRight()])
    gcMonitors()
    check(openLeft().setActiveWorkspace(Workspace.get(byName: "1")))
    check(openLaptop().setActiveWorkspace(Workspace.get(byName: "2")))
    check(openRight().setActiveWorkspace(Workspace.get(byName: "R")))
}

@MainActor
private func applyClosedTwoMonitors() {
    setTestMonitors([closedLeft(), closedRight()])
}

@MainActor
private func visibleSnapshot() -> [String] {
    Workspace.all
        .filter(\.isVisible)
        .map { "\($0.name)@\($0.workspaceMonitor.rect.topLeftX),\($0.workspaceMonitor.rect.topLeftY)" }
        .sorted()
}

@MainActor
private func assertReconcileInvariants() {
    let visibles = Workspace.all.filter(\.isVisible)
    let origins = visibles.map { "\($0.workspaceMonitor.rect.topLeftX),\($0.workspaceMonitor.rect.topLeftY)" }
    assertEquals(Set(origins).count, origins.count)
    assertEquals(visibles.count, monitorInfos.count)
    for monitor in monitorInfos {
        assertEquals(visibles.count(where: { $0.workspaceMonitor.rect.topLeftCorner == monitor.rect.topLeftCorner }), 1)
    }
}
