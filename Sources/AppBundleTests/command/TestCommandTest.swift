@testable import AppBundle
import Common
import XCTest

@MainActor
final class TestCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseCommandSucc(
            "test %{app-bundle-id} .= foo",
            TestCmdArgs(rawArgs: [])
                .copy(\.lhs, .initialized(.app(.appBundleId)))
                .copy(\.infixOperator, .initialized(.equals))
                .copy(\.rhs, .initialized("foo")),
        )
        testParseCommandFail("test %{foo} .= foo", msg: "ERROR: Can\'t parse \'foo\'.\n       Possible values: (window-id|window-is-fullscreen|window-title|window-layout|window-parent-container-layout|workspace|workspace-is-focused|workspace-is-visible|workspace-root-container-layout|app-bundle-id|app-name|app-pid|app-exec-path|app-bundle-path|monitor-id|monitor-appkit-nsscreen-screens-id|monitor-name|monitor-is-main)", exitCode: 2)
        testParseCommandFail("test foo .= foo", msg: "ERROR: Left hand side must be a single interpolation variable", exitCode: 2)
        testParseCommandFail("test foo%{app-bundle-id} .= foo", msg: "ERROR: Left hand side must be a single interpolation variable", exitCode: 2)
        testParseCommandFail("test", msg: "ERROR: Argument \'<lhs>\' is mandatory\nERROR: Argument \'<operator>\' is mandatory\nERROR: Argument \'<rhs>\' is mandatory", exitCode: 2)
        testParseCommandFail("test foo .= %{app-bundle-id}", msg: "ERROR: Left hand side must be a single interpolation variable\nERROR: Right hand side doesn\'t allow interpolation variables", exitCode: 2)
        testParseCommandFail("test %{app-bundle-id} .= %{app-bundle-id}", msg: "ERROR: Right hand side doesn\'t allow interpolation variables", exitCode: 2)
        testParseCommandFail("test %{newline} .= foo", msg: "ERROR: Can\'t parse \'newline\'.\n       Possible values: (window-id|window-is-fullscreen|window-title|window-layout|window-parent-container-layout|workspace|workspace-is-focused|workspace-is-visible|workspace-root-container-layout|app-bundle-id|app-name|app-pid|app-exec-path|app-bundle-path|monitor-id|monitor-appkit-nsscreen-screens-id|monitor-name|monitor-is-main)", exitCode: 2)
    }

    func testExec() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }

        assertEquals(
            try await parseCommand("test %{window-id} .= 1").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: [], exitCode: Int32ExitCode(rawValue: 0)),
        )

        assertEquals(
            try await parseCommand("test %{window-id} /= 1").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: [], exitCode: Int32ExitCode(rawValue: 1)),
        )

        assertEquals(
            try await parseCommand("test %{workspace-is-focused} .= foo").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: ["Can\'t convert String \'foo\' to Bool"], exitCode: Int32ExitCode(rawValue: 2)),
        )

        assertEquals(
            try await parseCommand("test %{workspace-is-focused} .~ foo").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: ["Interpolation variable: \'workspace-is-focused\' has type of \'bool\'.\nThe \'bool\' type is not compatible with \'.~\' operator."], exitCode: Int32ExitCode(rawValue: 2)),
        )
    }

    func testExecNoWindow() async throws {
        assertEquals(Workspace.get(byName: name).focusWorkspace(), true)

        assertEquals(
            try await parseCommand("test %{window-id} .= 1").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: ["Unknown interpolation variable \'window-id\'. Possible values:\n  workspace\n  workspace-is-focused\n  workspace-is-visible\n  workspace-root-container-layout\n  monitor-id\n  monitor-appkit-nsscreen-screens-id\n  monitor-name\n  monitor-is-main\n  right-padding\n  newline\n  tab", "No window is focused"], exitCode: Int32ExitCode(rawValue: 2)),
        )
    }
}
