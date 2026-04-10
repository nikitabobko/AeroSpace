@testable import AppBundle
import Common
import XCTest

@MainActor
final class TestCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseCommandSucc("test --app-id foo", TestCmdArgs(rawArgs: []).copy(\.appBundleId, "foo"))
        testParseCommandFail("test --app-id", msg: "ERROR: '--app-id' must be followed by '<app-bundle-id>'", exitCode: 2)
        testParseCommandFail("test --foo", msg: "ERROR: Unknown flag '--foo'", exitCode: 2)
    }
}
