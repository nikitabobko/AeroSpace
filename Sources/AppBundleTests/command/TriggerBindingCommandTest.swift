@testable import AppBundle
import Common
import XCTest

@MainActor
final class TriggerBindingCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseSingleCommandSucc("trigger-binding foo --mode main", TriggerBindingCmdArgs(rawArgs: []).with(\.binding, .initialized("foo")).with(\._mode, "main"))
        testParseCommandFail("trigger-binding foo", msg: "--mode flag is mandatory", exitCode: 2)
        testParseCommandFail("trigger-binding", msg: "ERROR: Argument \'<binding>\' is mandatory", exitCode: 2)
    }

    func testParseDoubleDash() {
        testParseSingleCommandSucc(
            "trigger-binding --mode main -- foo",
            TriggerBindingCmdArgs(rawArgs: []).with(\.binding, .initialized("foo")).with(\._mode, "main"),
        )
        testParseSingleCommandSucc(
            "trigger-binding --mode main -- --fail-if-noop",
            TriggerBindingCmdArgs(rawArgs: []).with(\.binding, .initialized("--fail-if-noop")).with(\._mode, "main"),
        )
        testParseCommandFail("trigger-binding --mode main --", msg: "ERROR: Argument '<binding>' is mandatory", exitCode: 2)
    }
}
