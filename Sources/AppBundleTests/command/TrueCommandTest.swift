@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct TrueCommandTest {
    init() { setUpWorkspacesForTests() }

    @Test func testParse() {
        testParseSingleCommandSucc("true", TrueCmdArgs(rawArgs: []))
        testParseCommandFail("true foo", msg: "ERROR: Unknown argument \'foo\'", exitCode: 2)

        testParseCommandHelp("true -h")
        testParseCommandHelp("true --help")
    }

    @Test func testExitCode() async {
        assertEquals(await parseCommand("true").cmdOrDie.run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
    }
}
