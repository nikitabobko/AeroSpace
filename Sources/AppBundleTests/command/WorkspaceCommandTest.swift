import XCTest
import Common
@testable import AppBundle

final class WorkspaceCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParseWorkspaceCommand() {
        testParseCommandFail("workspace my mail", msg: "ERROR: Unknown argument 'mail'")
        testParseCommandFail("workspace 'my mail'", msg: "ERROR: Whitespace characters are forbidden in workspace names")
        XCTAssertTrue(parseCommand("workspace").errorOrNil?.contains("mandatory") == true)
        testParseCommandSucc("workspace next", WorkspaceCmdArgs(rawArgs: [], .relative(WTarget.Relative(isNext: true, wrapAround: false))))
        testParseCommandSucc("workspace --auto-back-and-forth W", WorkspaceCmdArgs(rawArgs: [], .direct(WTarget.Direct("W", autoBackAndForth: true))))
        XCTAssertTrue(parseCommand("workspace --wrap-around W").errorOrNil?.contains("--wrap-around is allowed only for (next|prev)") == true)
        XCTAssertTrue(parseCommand("workspace --auto-back-and-forth next").errorOrNil?.contains("--auto-back-and-forth is not allowed for (next|prev)") == true)
        testParseCommandSucc("workspace next --wrap-around", WorkspaceCmdArgs(rawArgs: [], .relative(WTarget.Relative(isNext: true, wrapAround: true))))
    }
}
