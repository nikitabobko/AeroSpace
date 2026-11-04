@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct ExecCommandTest {
    init() { setUpWorkspacesForTests() }

    @Test func testParseExecCommand() {
        testParseSingleCommandSucc("exec-and-forget echo 'foo'", ExecAndForgetCmdArgs(bashScript: " echo 'foo'"))
    }
}
