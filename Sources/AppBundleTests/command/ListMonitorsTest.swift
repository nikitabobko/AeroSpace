import XCTest
import Common
@testable import AppBundle

final class ListMonitorsTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParseListMonitorsCommand() {
        testParseCommandSucc("list-monitors", ListMonitorsCmdArgs())
        testParseCommandSucc("list-monitors --focused", ListMonitorsCmdArgs().copy(\.focused, true))
    }
}
