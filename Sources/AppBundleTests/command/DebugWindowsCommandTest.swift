@testable import AppBundle
import Common
import XCTest

@MainActor
final class DebugWindowsCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseSingleCommandSucc("debug-windows", DebugWindowsCmdArgs(rawArgs: []))
        testParseSingleCommandSucc(
            "debug-windows --window-id 42",
            DebugWindowsCmdArgs(rawArgs: []).copy(\.windowId, 42),
        )
        testParseSingleCommandSucc(
            "debug-windows --app-bundle-id com.example.app",
            DebugWindowsCmdArgs(rawArgs: []).copy(\.appBundleId, "com.example.app"),
        )
    }
}
