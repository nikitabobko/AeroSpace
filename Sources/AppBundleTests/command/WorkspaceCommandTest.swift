@testable import AppBundle
import Common
import XCTest

final class WorkspaceCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParseWorkspaceCommand() {
        testParseCommandFail("workspace my mail", msg: "ERROR: Unknown argument 'mail'")
        testParseCommandFail("workspace 'my mail'", msg: "ERROR: Whitespace characters are forbidden in workspace names")
        XCTAssertTrue(parseCommand("workspace").errorOrNil?.contains("mandatory") == true)
        testParseCommandSucc("workspace next", WorkspaceCmdArgs(target: .relative(true)))
        testParseCommandSucc("workspace --auto-back-and-forth W", WorkspaceCmdArgs(target: .direct(.parse("W").getOrThrow()), autoBackAndForth: true))
        XCTAssertTrue(parseCommand("workspace --wrap-around W").errorOrNil?.contains("--wrap-around is allowed only for (next|prev)") == true)
        XCTAssertTrue(parseCommand("workspace --auto-back-and-forth next").errorOrNil?.contains("--auto-back-and-forth is not allowed for (next|prev)") == true)
        testParseCommandSucc("workspace next --wrap-around", WorkspaceCmdArgs(target: .relative(true), wrapAround: true))
    }
}
