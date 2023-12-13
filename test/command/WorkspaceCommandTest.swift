import XCTest
@testable import AeroSpace_Debug

final class WorkspaceCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParseWorkspaceCommand() {
        testParseCommandFail("workspace my mail", msg: "ERROR: Unknown argument 'mail'")
        testParseCommandFail("workspace 'my mail'", msg: "Quotation marks are reserved for future use")
        XCTAssertTrue(parseCommand("workspace").failureMsgOrNil?.contains("mandatory") == true)
        XCTAssertEqual(
            parseCommand("workspace next").cmdOrNil?.describe,
            .workspace(args: WorkspaceCmdArgs(target: .next, autoBackAndForth: false))
        )
        XCTAssertEqual(
            parseCommand("workspace --auto-back-and-forth next").cmdOrNil?.describe,
            .workspace(args: WorkspaceCmdArgs(target: .next, autoBackAndForth: true))
        )
    }
}
