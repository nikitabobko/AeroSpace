import XCTest
import Common
@testable import AeroSpace_Debug

final class ListMonitorsTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParseListMonitorsCommand() {
        XCTAssertEqual(parseCommand("list-monitors").cmdOrNil?.describe, .listMonitors(args: ListMonitorsCmdArgs()))
        XCTAssertEqual(parseCommand("list-monitors --focused").cmdOrNil?.describe, .listMonitors(args: ListMonitorsCmdArgs().copy(\.focused, true)))
    }
}
