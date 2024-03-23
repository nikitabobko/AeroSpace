import XCTest
@testable import AppBundle

final class ExecCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParseExecCommand() {
        testParseCommandSucc("exec-and-forget echo 'foo'", .execAndForget(" echo 'foo'"))
    }
}
