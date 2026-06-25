@testable import AppBundle
import Common
import XCTest

@MainActor
final class ShellRunTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testOrFirstSucceeds_shortCircuits() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("true || workspace b").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.workspace.name, "a")
    }

    func testOrFirstFails_runsNext() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("false || workspace b").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.workspace.name, "b")
    }

    func testOrAllFail_returnsLastExitCode() async {
        let result = await parseCommand("false || false || false").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 1)
    }

    func testOrChainStopsOnFirstSuccess() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("false || workspace b || workspace c").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.workspace.name, "b")
    }

    func testAndFirstFails_shortCircuits() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("false && workspace b").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 1)
        assertEquals(focus.workspace.name, "a")
    }

    func testAndAllSucceed_returnsZero() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("true && workspace b").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.workspace.name, "b")
    }

    func testAndChainStopsOnFirstFailure() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("workspace b && false && workspace c").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 1)
        assertEquals(focus.workspace.name, "b")
    }

    func testAndReturnsLastSuccessExitCode() async {
        let result = await parseCommand("true && true && true").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
    }

    func testSeqRunsAllRegardlessOfExitCode() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("false; workspace b").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.workspace.name, "b")
    }

    func testSeqReturnsLastCommandExitCode() async {
        let succThenFail = await parseCommand("true; false").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(succThenFail.exitCode.rawValue, 1)

        let failThenSucc = await parseCommand("false; true").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(failThenSucc.exitCode.rawValue, 0)
    }

    func testSeqConcatenatesStdout() async {
        let result = await parseCommand("echo -- foo; echo -- bar; echo -- baz").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["foo", "bar", "baz"])
    }

    func testPipeForwardsStdoutAsStdin() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("echo -- a b c | workspace --stdin next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.workspace.name, "b")
    }

    func testPipeReturnsOnlyLastStdout() async {
        let result = await parseCommand("echo -- foo | echo -- bar").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["bar"])
    }

    func testPipeForwardsIntermediateStderr() async {
        let result = await parseCommand("echo --stderr -- err1 | echo -- out2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["out2"])
        assertEquals(result.stderr, ["err1"])
    }

    func testPipePipefailReturnsRightmostNonZero() async {
        let leftFails = await parseCommand("false | true").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(leftFails.exitCode.rawValue, 1)

        let rightFails = await parseCommand("true | false").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(rightFails.exitCode.rawValue, 1)

        let allSucceed = await parseCommand("true | true").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(allSucceed.exitCode.rawValue, 0)
    }

    func testPipeForwardsOriginalStdin() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("workspace --stdin next | echo -- done")
            .cmdOrDie.run(.defaultEnv, CmdStdin("a\nb\nc\n"))
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["done"])
        assertEquals(focus.workspace.name, "b")
    }
}
