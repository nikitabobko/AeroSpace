import XCTest
@testable import AeroSpace_Debug

final class ExecCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParseExecCommand() {
        testParseCommandSucc("exec-and-forget echo 'foo'", .execAndForget(" echo 'foo'"))
    }
}
