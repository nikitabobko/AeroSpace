@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct ListMonitorsTest {
    @Test func testParseListMonitorsCommand() {
        testParseSingleCommandSucc("list-monitors", ListMonitorsCmdArgs(rawArgs: []))
        testParseSingleCommandSucc("list-monitors --focused", ListMonitorsCmdArgs(rawArgs: []).with(\.focused, true))
        testParseSingleCommandSucc("list-monitors --count", ListMonitorsCmdArgs(rawArgs: []).with(\.outputOnlyCount, true))
        assertEquals(parseCommand("list-monitors --format %{monitor-id} --count").errorOrNil, "ERROR: Conflicting flags: --count, --format")
    }
}
