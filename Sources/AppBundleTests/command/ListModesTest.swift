@testable import AppBundle
import Common
import XCTest

final class ListModesTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParseListModesCommand() {
        testParseCommandSucc("list-modes", ListModesCmdArgs(rawArgs: []))
        testParseCommandSucc("list-modes --current", ListModesCmdArgs(rawArgs: []).copy(\.current, true))
    }
}
