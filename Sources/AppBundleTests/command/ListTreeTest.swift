@testable import AppBundle
import Common
import XCTest

final class ListTreeTest: XCTestCase {
    func testParseListTreeCommand() {
        testParseCommandSucc("list-tree", ListTreeCmdArgs(rawArgs: []))
    }
}
