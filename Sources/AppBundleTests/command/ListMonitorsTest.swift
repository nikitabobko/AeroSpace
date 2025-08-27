@testable import AppBundle
import Common
import XCTest

final class ListMonitorsTest: XCTestCase {
    func testParseListMonitorsCommand() {
        testParseCommandSucc("list-monitors", ListMonitorsCmdArgs(rawArgs: []))
        testParseCommandSucc("list-monitors --focused", ListMonitorsCmdArgs(rawArgs: []).copy(\.focused, true))
        testParseCommandSucc("list-monitors --count", ListMonitorsCmdArgs(rawArgs: []).copy(\.outputOnlyCount, true))
        assertEquals(parseCommand("list-monitors --format %{monitor-id} --count").errorOrNil, "ERROR: Conflicting options: --count, --format")
    }

    func testMonitorIsMainFormatVariable() {
        testParseCommandSucc("list-monitors --format %{monitor-is-main}",
                             ListMonitorsCmdArgs(rawArgs: []).copy(\._format, [.interVar("monitor-is-main")]))
        testParseCommandSucc("list-monitors --format '%{monitor-name} %{monitor-is-main}'",
                             ListMonitorsCmdArgs(rawArgs: []).copy(\._format, [.interVar("monitor-name"), .literal(" "), .interVar("monitor-is-main")]))
    }
}
