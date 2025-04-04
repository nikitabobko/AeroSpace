@testable import AppBundle
import Common
import XCTest

final class ListModesTest: XCTestCase {
    func testParseListModesCommand() {
        testParseCommandSucc("list-modes", ListModesCmdArgs(rawArgs: []))
        testParseCommandSucc("list-modes --current", ListModesCmdArgs(rawArgs: []).copy(\.current, true))
        testParseCommandSucc("list-modes --json", ListModesCmdArgs(rawArgs: []).copy(\.json, true))
    }
}
