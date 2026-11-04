@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct ModeCommandTest {
    init() { setUpWorkspacesForTests() }

    @Test func testParse() {
        testParseSingleCommandSucc("mode main", ModeCmdArgs(rawArgs: []).with(\.targetMode, .initialized("main")))
        assertEquals(parseCommand("mode").errorOrNil, "ERROR: Argument '<binding-mode>' is mandatory")
    }

    @Test func testParseDoubleDash() {
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
