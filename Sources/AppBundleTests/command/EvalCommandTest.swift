@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct EvalCommandTest {
    init() { setUpWorkspacesForTests() }

    @Test func testParse() {
        testParseSingleCommandSucc("eval 'workspace foo'", EvalCmdArgs(rawArgs: []).with(\.shellExpr, .initialized("workspace foo")))
        assertEquals(parseCommand("eval").errorOrNil, "ERROR: Argument '<aerospace-shell-expr>' is mandatory")
    }

    @Test func testParseDoubleDash() {
        testParseSingleCommandSucc(
            "eval -- '--anything'",
            EvalCmdArgs(rawArgs: []).with(\.shellExpr, .initialized("--anything")),
        )
        assertEquals(parseCommand("eval --").errorOrNil, "ERROR: Argument '<aerospace-shell-expr>' is mandatory")
    }

    @Test func testRunSimpleCommand() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("eval 'workspace b'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, [])
        assertEquals(globalFocus.workspace.name, "b")
    }

    @Test func testRunForwardsStdout() async {
        assertTrue(Workspace.get(byName: name).focusWorkspace())

        let result = await parseCommand("eval 'echo -- hello'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["hello"])
        assertEquals(result.stderr, [])
    }

    @Test func testRunShellComposition() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("eval 'workspace a && workspace b'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(globalFocus.workspace.name, "b")
    }

    @Test func testRunEmptyShellExpr() async {
        assertTrue(Workspace.get(byName: name).focusWorkspace())

        let result = await parseCommand("eval ''").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, [])
    }

    @Test func testRunUnrecognizedSubcommand() async {
        assertTrue(Workspace.get(byName: name).focusWorkspace())

        let result = await parseCommand("eval 'no-such-command'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["Unrecognized subcommand 'no-such-command'"])
    }

    @Test func testRunInnerParseFailureForwardsErrorAndExitCode() async {
        assertTrue(Workspace.get(byName: name).focusWorkspace())

        let result = await parseCommand("eval 'workspace'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["ERROR: Argument '(<workspace-name>|next|prev)' is mandatory"])
    }

    @Test func testRunRejectsInnerHelp() async {
        assertTrue(Workspace.get(byName: name).focusWorkspace())

        let result = await parseCommand("eval 'workspace --help'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["--help is not supported inside eval command"])
    }

    @Test func testRunNestedEval() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("eval 'eval \"workspace b\"'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Illegal eval (Tip: nested evals are forbidden)"])
        assertEquals(globalFocus.workspace.name, "a")
    }
}
