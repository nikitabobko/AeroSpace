@testable import AppBundle
import Common
import XCTest

@MainActor
final class ModeCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseSingleCommandSucc("mode main", ModeCmdArgs(rawArgs: []).with(\.targetMode, .initialized("main")))
        assertEquals(parseCommand("mode").errorOrNil, "ERROR: Argument '<binding-mode>' is mandatory")
    }

    func testParseDoubleDash() {
        testParseSingleCommandSucc(
            "mode -- main",
            ModeCmdArgs(rawArgs: []).with(\.targetMode, .initialized("main")),
        )
        testParseSingleCommandSucc(
            "mode -- --foo",
            ModeCmdArgs(rawArgs: []).with(\.targetMode, .initialized("--foo")),
        )
        assertEquals(parseCommand("mode --").errorOrNil, "ERROR: Argument '<binding-mode>' is mandatory")
    }
}
