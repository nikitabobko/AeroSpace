@testable import AppBundle
import Common
import XCTest

final class ListMonitorsTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParseListMonitorsCommand() {
        testParseCommandSucc("list-monitors", ListMonitorsCmdArgs(rawArgs: []))
        testParseCommandSucc("list-monitors --focused", ListMonitorsCmdArgs(rawArgs: []).copy(\.focused, true))
        testParseCommandSucc("list-monitors --count", ListMonitorsCmdArgs(rawArgs: []).copy(\.outputOnlyCount, true))
        assertEquals(parseCommand("list-monitors --format %{monitor-id} --count").errorOrNil, "ERROR: Conflicting options: --count, --format")
    }
}
