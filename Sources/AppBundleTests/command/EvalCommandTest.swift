@testable import AppBundle
import Common
import XCTest

@MainActor
final class EvalCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseSingleCommandSucc("eval 'workspace foo'", EvalCmdArgs(rawArgs: []).copy(\.shellExpr, .initialized("workspace foo")))
        assertEquals(parseCommand("eval").errorOrNil, "ERROR: Argument '<aerospace-shell-expr>' is mandatory")
    }

    func testParseDashDash() {
        testParseSingleCommandSucc(
            "eval -- '--anything'",
            EvalCmdArgs(rawArgs: []).copy(\.shellExpr, .initialized("--anything")),
        )
        assertEquals(parseCommand("eval --").errorOrNil, "ERROR: Argument '<aerospace-shell-expr>' is mandatory")
    }
}
