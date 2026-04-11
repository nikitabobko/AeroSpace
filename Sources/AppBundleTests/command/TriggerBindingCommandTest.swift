@testable import AppBundle
import Common
import XCTest

@MainActor
final class TriggerBindingCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseCommandSucc("trigger-binding foo --mode main", TriggerBindingCmdArgs(rawArgs: []).copy(\.binding, .initialized("foo")).copy(\._mode, "main"))
        testParseCommandFail("trigger-binding foo", msg: "--mode flag is mandatory", exitCode: 2)
        testParseCommandFail("trigger-binding", msg: "ERROR: Argument \'<binding>\' is mandatory", exitCode: 2)
    }
}
