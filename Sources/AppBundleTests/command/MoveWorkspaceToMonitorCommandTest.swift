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
}

@MainActor
private func parseMoveWorkspaceToMonitorTarget(_ raw: String) -> MonitorTarget? {
    guard case .cmd(.cmd(let cmd)) = parseCommand(raw),
          let args = cmd.args as? MoveWorkspaceToMonitorCmdArgs
    else { return nil }
    return args.target.val
}
