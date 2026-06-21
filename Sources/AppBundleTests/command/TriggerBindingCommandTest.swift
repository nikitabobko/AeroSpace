@testable import AppBundle
import Common
import XCTest

@MainActor
final class TriggerBindingCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseSingleCommandSucc("trigger-binding foo --mode main", TriggerBindingCmdArgs(rawArgs: []).copy(\.binding, .initialized("foo")).copy(\._mode, "main"))
        testParseCommandFail("trigger-binding foo", msg: "--mode flag is mandatory", exitCode: 2)
        testParseCommandFail("trigger-binding", msg: "ERROR: Argument \'<binding>\' is mandatory", exitCode: 2)
    }

    func testParseDashDash() {
        testParseSingleCommandSucc(
            "trigger-binding --mode main -- foo",
            TriggerBindingCmdArgs(rawArgs: []).copy(\.binding, .initialized("foo")).copy(\._mode, "main"),
        )
        testParseSingleCommandSucc(
            "trigger-binding --mode main -- --fail-if-noop",
            TriggerBindingCmdArgs(rawArgs: []).copy(\.binding, .initialized("--fail-if-noop")).copy(\._mode, "main"),
        )
        testParseCommandFail("trigger-binding --mode main --", msg: "ERROR: Argument '<binding>' is mandatory", exitCode: 2)
    }
}
