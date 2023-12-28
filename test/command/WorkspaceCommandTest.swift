import XCTest
import Common
@testable import AeroSpace_Debug

final class WorkspaceCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParseWorkspaceCommand() {
        testParseCommandFail("workspace my mail", msg: "ERROR: Unknown argument 'mail'")
        testParseCommandFail("workspace 'my mail'", msg: "Quotation marks and backslash are reserved for future use")
        XCTAssertTrue(parseCommand("workspace").failureMsgOrNil?.contains("mandatory") == true)
        XCTAssertEqual(
            parseCommand("workspace next").cmdOrNil?.describe,
            .workspace(args: WorkspaceCmdArgs(.relative(WTarget.Relative(isNext: true, wrapAround: false))))
        )
        XCTAssertEqual(
            parseCommand("workspace --auto-back-and-forth W").cmdOrNil?.describe,
            .workspace(args: WorkspaceCmdArgs(.direct(WTarget.Direct(name: "W", autoBackAndForth: true))))
        )
        XCTAssertTrue(parseCommand("workspace --wrap-around W").failureMsgOrNil?.contains("--wrap-around is allowed only for (next|prev)") == true)
        XCTAssertTrue(parseCommand("workspace --auto-back-and-forth next").failureMsgOrNil?.contains("--auto-back-and-forth is not allowed for (next|prev)") == true)
        XCTAssertEqual(
            parseCommand("workspace next --wrap-around").cmdOrNil?.describe,
            .workspace(args: WorkspaceCmdArgs(.relative(WTarget.Relative(isNext: true, wrapAround: true))))
        )
    }
}
