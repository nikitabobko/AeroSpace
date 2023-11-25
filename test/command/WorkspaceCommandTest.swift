import XCTest
@testable import AeroSpace_Debug

final class WorkspaceCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParseWorkspaceCommand() {
        testParseCommandFail("workspace my mail", msg: "'workspace' command must have only a single argument. But passed: 'my mail' (2 args)")
        testParseCommandFail("workspace 'my mail'", msg: "Quotation marks are reserved for future use")
    }
}
