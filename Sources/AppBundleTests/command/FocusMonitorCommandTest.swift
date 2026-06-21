@testable import AppBundle
import Common
import XCTest

@MainActor
final class FocusMonitorCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        assertEquals(parseFocusMonitorTarget("focus-monitor next"), .relative(.next))
        assertEquals(parseFocusMonitorTarget("focus-monitor left"), .direction(.left))
        assertEquals(parseFocusMonitorTarget("focus-monitor main"), .patterns([.main]))
        assertEquals(parseCommand("focus-monitor --wrap-around main").errorOrNil, "--wrap-around is incompatible with <monitor-pattern> argument")
    }

    func testParseDashDash() {
        assertEquals(parseFocusMonitorTarget("focus-monitor -- next"), .patterns([.pattern("next")!]))
        assertEquals(parseFocusMonitorTarget("focus-monitor -- main 2"), .patterns([.main, .sequenceNumber(2)]))
        assertEquals(parseCommand("focus-monitor --").errorOrNil, "ERROR: Argument \'(left|down|up|right|next|prev|<monitor-pattern>)\' is mandatory")
    }
}

@MainActor
private func parseFocusMonitorTarget(_ raw: String) -> MonitorTarget? {
    guard case .cmd(.cmd(let cmd)) = parseCommand(raw),
          let args = cmd.args as? FocusMonitorCmdArgs
    else { return nil }
    return args.target.val
}
