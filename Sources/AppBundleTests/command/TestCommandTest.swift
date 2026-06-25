@testable import AppBundle
import Common
import XCTest

@MainActor
final class TestCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseSingleCommandSucc(
            "test %{app-bundle-id} = foo",
            TestCmdArgs(rawArgs: [])
                .copy(\.lhs, .initialized(.app(.appBundleId)))
                .copy(\.infixOperator, .initialized(.equals))
                .copy(\.rhs, .initialized("foo")),
        )
        testParseSingleCommandSucc(
            "test-not %{app-bundle-id} ~= foo",
            TestNotCmdArgs(rawArgs: [])
                .copy(\.testArgs.lhs, .initialized(.app(.appBundleId)))
                .copy(\.testArgs.infixOperator, .initialized(.matchesRegex))
                .copy(\.testArgs.rhs, .initialized("foo")),
        )

        testParseCommandFail("test %{foo} = foo", msg: "ERROR: Can\'t parse \'foo\'.\n       Possible values: (window-id|window-is-fullscreen|window-title|window-layout|window-parent-container-layout|workspace|workspace-is-focused|workspace-is-visible|workspace-root-container-layout|app-bundle-id|app-name|app-pid|app-exec-path|app-bundle-path|monitor-id|monitor-appkit-nsscreen-screens-id|monitor-name|monitor-is-main)", exitCode: 2)
        testParseCommandFail("test foo = foo", msg: "ERROR: Left hand side must be a single interpolation variable", exitCode: 2)
        testParseCommandFail("test foo%{app-bundle-id} = foo", msg: "ERROR: Left hand side must be a single interpolation variable", exitCode: 2)
        testParseCommandFail("test", msg: "ERROR: Argument \'<lhs>\' is mandatory\nERROR: Argument \'<operator>\' is mandatory\nERROR: Argument \'<rhs>\' is mandatory", exitCode: 2)
        testParseCommandFail("test foo = %{app-bundle-id}", msg: "ERROR: Left hand side must be a single interpolation variable\nERROR: Right hand side doesn\'t allow interpolation variables", exitCode: 2)
        testParseCommandFail("test %{app-bundle-id} = %{app-bundle-id}", msg: "ERROR: Right hand side doesn\'t allow interpolation variables", exitCode: 2)
        testParseCommandFail("test %{newline} = foo", msg: "ERROR: Can\'t parse \'newline\'.\n       Possible values: (window-id|window-is-fullscreen|window-title|window-layout|window-parent-container-layout|workspace|workspace-is-focused|workspace-is-visible|workspace-root-container-layout|app-bundle-id|app-name|app-pid|app-exec-path|app-bundle-path|monitor-id|monitor-appkit-nsscreen-screens-id|monitor-name|monitor-is-main)", exitCode: 2)
        testParseCommandFail("test %{window-id} = %{invalid}", msg: "ERROR: Right hand side doesn\'t allow interpolation variables", exitCode: 2)
    }

    func testExec() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }

        assertEquals(
            await parseCommand("test %{window-id} = 1").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: [], exitCode: Int32ExitCode(rawValue: 0)),
        )

        assertEquals(
            await parseCommand("test %{window-id} = 2").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: [], exitCode: Int32ExitCode(rawValue: 1)),
        )

        assertEquals(
            await parseCommand("test %{workspace-is-focused} = foo").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: ["Can\'t convert String \'foo\' to Bool"], exitCode: Int32ExitCode(rawValue: 2)),
        )

        assertEquals(
            await parseCommand("test %{workspace-is-focused} ~= foo").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: ["Interpolation variable: \'workspace-is-focused\' has a type of Bool. The Bool type is not compatible with \'~=\' operator."], exitCode: Int32ExitCode(rawValue: 2)),
        )
    }

    func testExecNoWindow() async {
        assertEquals(Workspace.get(byName: name).focusWorkspace(), true)

        assertEquals(
            await parseCommand("test %{window-id} = 1").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: ["No window is focused"], exitCode: Int32ExitCode(rawValue: 2)),
        )
    }

    func testExecWorkspaceContextSuccess() async {
        // Exercises the workspace-only branch of `_lhs` where no window is focused
        // and the lhs interpolation variable resolves against the workspace target.
        assertEquals(Workspace.get(byName: name).focusWorkspace(), true)

        assertEquals(
            await parseCommand("test %{workspace-is-focused} = true").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: [], exitCode: Int32ExitCode(rawValue: 0)),
        )
    }

    func testExecBoolEquals() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }

        assertEquals(
            await parseCommand("test %{workspace-is-focused} = true").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: [], exitCode: Int32ExitCode(rawValue: 0)),
        )

        assertEquals(
            await parseCommand("test %{workspace-is-focused} = false").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: [], exitCode: Int32ExitCode(rawValue: 1)),
        )
    }

    func testExecIntEqualsRhsNotInt() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }

        assertEquals(
            await parseCommand("test %{window-id} = abc").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: ["Can\'t convert String \'abc\' to Int"], exitCode: Int32ExitCode(rawValue: 2)),
        )
    }

    func testExecIntMatchesRegexIncompatible() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }

        assertEquals(
            await parseCommand("test %{window-id} ~= 1").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: ["Interpolation variable: \'window-id\' has a type of Int. The Int type is not compatible with \'~=\' operator."], exitCode: Int32ExitCode(rawValue: 2)),
        )
    }

    func testExecStringEquals() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }

        assertEquals(
            await parseCommand("test %{app-bundle-id} = bobko.AeroSpace.test-app").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: [], exitCode: Int32ExitCode(rawValue: 0)),
        )

        assertEquals(
            await parseCommand("test %{app-bundle-id} = other.bundle.id").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: [], exitCode: Int32ExitCode(rawValue: 1)),
        )
    }

    func testExecStringMatchesRegex() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }

        assertEquals(
            await parseCommand("test %{app-bundle-id} ~= AERO").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: [], exitCode: Int32ExitCode(rawValue: 0)),
        )

        assertEquals(
            await parseCommand("test %{app-bundle-id} ~= zzzzz").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: [], exitCode: Int32ExitCode(rawValue: 1)),
        )
    }

    func testExecStringMatchesRegexInvalidPattern() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }

        let result = await parseCommand("test %{app-bundle-id} ~= [").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertTrue(result.stderr.first?.contains("Can\'t parse \'[\' regex") ?? false)
    }

    func testExecTargetResolutionFailure() async {
        assertEquals(Workspace.get(byName: name).focusWorkspace(), true)
        let env = CmdEnv.defaultEnv.withWindowId(9999)

        assertEquals(
            await parseCommand("test %{window-id} = 1").cmdOrDie.run(env, .emptyStdin),
            CmdResult(stdout: [], stderr: ["Invalid <window-id> 9999 specified in AEROSPACE_WINDOW_ID env variable"], exitCode: Int32ExitCode(rawValue: 2)),
        )
    }

    func testNotExec() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }

        // test inner=true → test-not=false
        assertEquals(
            await parseCommand("test-not %{window-id} = 1").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: [], exitCode: Int32ExitCode(rawValue: 1)),
        )

        // test inner=false → test-not=true
        assertEquals(
            await parseCommand("test-not %{window-id} = 2").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: [], exitCode: Int32ExitCode(rawValue: 0)),
        )

        // test inner=fail → test-not=fail (propagates without inverting)
        assertEquals(
            await parseCommand("test-not %{workspace-is-focused} = foo").cmdOrDie.run(.defaultEnv, .emptyStdin),
            CmdResult(stdout: [], stderr: ["Can\'t convert String \'foo\' to Bool"], exitCode: Int32ExitCode(rawValue: 2)),
        )
    }
}
