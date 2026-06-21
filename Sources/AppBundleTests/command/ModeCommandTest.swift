@testable import AppBundle
import Common
import XCTest

@MainActor
final class ModeCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseSingleCommandSucc("mode main", ModeCmdArgs(rawArgs: []).copy(\.targetMode, .initialized("main")))
        assertEquals(parseCommand("mode").errorOrNil, "ERROR: Argument '<binding-mode>' is mandatory")
    }

    func testParseDashDash() {
        testParseSingleCommandSucc(
            "mode -- main",
            ModeCmdArgs(rawArgs: []).copy(\.targetMode, .initialized("main")),
        )
        testParseSingleCommandSucc(
            "mode -- --foo",
            ModeCmdArgs(rawArgs: []).copy(\.targetMode, .initialized("--foo")),
        )
        assertEquals(parseCommand("mode --").errorOrNil, "ERROR: Argument '<binding-mode>' is mandatory")
    }
}
