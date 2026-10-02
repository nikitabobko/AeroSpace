@testable import AppBundle
import Common
import XCTest

@MainActor
final class MoveWorkspaceToMonitorCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        assertEquals(parseMoveWorkspaceToMonitorTarget("move-workspace-to-monitor next"), .relative(.next))
        assertEquals(parseMoveWorkspaceToMonitorTarget("move-workspace-to-monitor main"), .patterns([.main]))
    }

    func testParseDashDash() {
        assertEquals(parseMoveWorkspaceToMonitorTarget("move-workspace-to-monitor -- next"), .patterns([.pattern("next")!]))
        assertEquals(parseCommand("move-workspace-to-monitor --").errorOrNil, "ERROR: Argument \'(left|down|up|right|next|prev|<monitor-pattern>)\' is mandatory")
    }

    func testMoveWorkspaceToMonitor() async {
        let monitors = setUpMonitorsForTests([
            Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
        ])
        let workspaceA = Workspace.get(byName: "a").apply {
            assertTrue(TestWindow.new(id: 1, parent: $0.rootTilingContainer).focusWindow())
        }

        let result = await parseCommand("move-workspace-to-monitor right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(monitors[1].activeWorkspace, workspaceA)
        assertTrue(monitors[0].activeWorkspace.isEffectivelyEmpty)
        assertEquals(focus.workspace, workspaceA)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testMoveWorkspaceToMonitor_forceAssignment() async {
        config.workspaceToMonitorForceAssignment = ["a": [.main]]
        let monitors = setUpMonitorsForTests([
            Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
        ])
        let workspaceA = Workspace.get(byName: "a")
        assertTrue(workspaceA.focusWorkspace())

        let result = await parseCommand("move-workspace-to-monitor right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(
            result.stderr,
            ["Can't move workspace 'a' to monitor 'Test Monitor 2'. workspace-to-monitor-force-assignment doesn't allow it"],
        )
        assertEquals(monitors[0].activeWorkspace, workspaceA)
    }
}

@MainActor
private func parseMoveWorkspaceToMonitorTarget(_ raw: String) -> MonitorTarget? {
    guard case .cmd(.cmd(let cmd)) = parseCommand(raw),
          let args = cmd.args as? MoveWorkspaceToMonitorCmdArgs
    else { return nil }
    return args.target.val
}
