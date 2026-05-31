@testable import AppBundle
import Common
import XCTest

@MainActor
final class SummonWorkspaceCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        assertEquals(parseCommand("summon-workspace").errorOrNil, "ERROR: Argument '<workspace>' is mandatory")
    }

    func testSummonVisibleWorkspaceUsesPreviousWorkspaceAsStub() async throws {
        setUpTwoTestMonitors()
        let secondaryMonitor = monitors[1]
        check(secondaryMonitor.setActiveWorkspace(Workspace.get(byName: "a")))
        check(secondaryMonitor.setActiveWorkspace(Workspace.get(byName: "z")))
        check(secondaryMonitor.setActiveWorkspace(Workspace.get(byName: "m")))

        let result = try await parseCommand("summon-workspace m").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(mainMonitor.activeWorkspace.name, "m")
        assertEquals(secondaryMonitor.activeWorkspace.name, "z")
    }

    func testSummonWorkspaceRejectsForceAssignedWorkspace() async throws {
        setUpTwoTestMonitors()
        let secondaryMonitor = monitors[1]
        check(secondaryMonitor.setActiveWorkspace(Workspace.get(byName: "m")))
        config.workspaceToMonitorForceAssignment["m"] = [.secondary]
        let mainWorkspaceBefore = mainMonitor.activeWorkspace.name

        let result = try await parseCommand("summon-workspace m").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(mainMonitor.activeWorkspace.name, mainWorkspaceBefore)
        assertEquals(secondaryMonitor.activeWorkspace.name, "m")
    }
}
