@testable import AppBundle
import Common
import XCTest

@MainActor
final class ExecCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParseExecCommand() {
        testParseCommandSucc("exec-and-forget echo 'foo'", ExecAndForgetCmdArgs(bashScript: " echo 'foo'"))
    }
}
