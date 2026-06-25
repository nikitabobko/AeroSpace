@testable import AppBundle
import Common
import XCTest

@MainActor
final class EvalCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseSingleCommandSucc("eval 'workspace foo'", EvalCmdArgs(rawArgs: []).copy(\.shellExpr, .initialized("workspace foo")))
        assertEquals(parseCommand("eval").errorOrNil, "ERROR: Argument '<aerospace-shell-expr>' is mandatory")
    }

    func testParseDashDash() {
        testParseSingleCommandSucc(
            "eval -- '--anything'",
            EvalCmdArgs(rawArgs: []).copy(\.shellExpr, .initialized("--anything")),
        )
        assertEquals(parseCommand("eval --").errorOrNil, "ERROR: Argument '<aerospace-shell-expr>' is mandatory")
    }

    func testRunSimpleCommand() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("eval 'workspace b'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, [])
        assertEquals(focus.workspace.name, "b")
    }

    func testRunForwardsStdout() async {
        assertTrue(Workspace.get(byName: name).focusWorkspace())

        let result = await parseCommand("eval 'echo -- hello'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["hello"])
        assertEquals(result.stderr, [])
    }

    func testRunShellComposition() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("eval 'workspace a && workspace b'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.workspace.name, "b")
    }

    func testRunEmptyShellExpr() async {
        assertTrue(Workspace.get(byName: name).focusWorkspace())

        let result = await parseCommand("eval ''").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, [])
    }

    func testRunUnrecognizedSubcommand() async {
        assertTrue(Workspace.get(byName: name).focusWorkspace())

        let result = await parseCommand("eval 'no-such-command'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["Unrecognized subcommand 'no-such-command'"])
    }

    func testRunInnerParseFailureForwardsErrorAndExitCode() async {
        assertTrue(Workspace.get(byName: name).focusWorkspace())

        let result = await parseCommand("eval 'workspace'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["ERROR: Argument '(<workspace-name>|next|prev)' is mandatory"])
    }

    func testRunRejectsInnerHelp() async {
        assertTrue(Workspace.get(byName: name).focusWorkspace())

        let result = await parseCommand("eval 'workspace --help'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["--help is not supported inside eval command"])
    }

    func testRunNestedEval() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("eval 'eval \"workspace b\"'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Illegal eval (Tip: nested evals are forbidden)"])
        assertEquals(focus.workspace.name, "a")
    }
}
