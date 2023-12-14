import XCTest
@testable import AeroSpace_Debug

final class WorkspaceCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParseWorkspaceCommand() {
        testParseCommandFail("workspace my mail", msg: "ERROR: Unknown argument 'mail'")
        testParseCommandFail("workspace 'my mail'", msg: "Quotation marks are reserved for future use")
        XCTAssertTrue(parseCommand("workspace").failureMsgOrNil?.contains("mandatory") == true)
    }
}
