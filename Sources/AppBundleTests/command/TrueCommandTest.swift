@testable import AppBundle
import Common
import XCTest

@MainActor
final class TrueCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseSingleCommandSucc("true", TrueCmdArgs(rawArgs: []))
        testParseCommandFail("true foo", msg: "ERROR: Unknown argument \'foo\'", exitCode: 2)

        testParseCommandHelp("true -h")
        testParseCommandHelp("true --help")
    }

    func testExitCode() async {
        assertEquals(await parseCommand("true").cmdOrDie.run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
    }
}
