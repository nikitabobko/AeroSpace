@testable import AppBundle
import Common
import XCTest

@MainActor
final class FalseCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseSingleCommandSucc("false", FalseCmdArgs(rawArgs: []))
        testParseCommandFail("false foo", msg: "ERROR: Unknown argument 'foo'", exitCode: 2)

        testParseCommandHelp("false -h")
        testParseCommandHelp("false --help")
    }

    func testExitCode() async {
        assertEquals(await parseCommand("false").cmdOrDie.run(.defaultEnv, .emptyStdin).exitCode.rawValue, 1)
    }
}
