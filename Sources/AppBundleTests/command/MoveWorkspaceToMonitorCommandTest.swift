@testable import AppBundle
import Common
import XCTest

@MainActor
final class MoveWorkspaceToMonitorCommandTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        setUpTwoTestMonitors()
    }

    func testMoveWorkspaceToMonitorUsesPreviousWorkspaceAsStub() async throws {
        check(Workspace.get(byName: "a").focusWorkspace())
        check(Workspace.get(byName: "z").focusWorkspace())
        check(Workspace.get(byName: "m").focusWorkspace())

        let result = try await parseCommand("move-workspace-to-monitor next").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(mainMonitor.activeWorkspace.name, "z")
        assertEquals(monitors[1].activeWorkspace.name, "m")
    }

    func testMoveWorkspaceToMonitorRejectsForceAssignedWorkspace() async throws {
        check(Workspace.get(byName: "m").focusWorkspace())
        config.workspaceToMonitorForceAssignment["m"] = [.main]

        let result = try await parseCommand("move-workspace-to-monitor next").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(mainMonitor.activeWorkspace.name, "m")
    }
}
