@testable import AppBundle
import Common
import XCTest

@MainActor
final class WorkspaceCommandTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        _prevFocusedWorkspaceName = nil
    }

    func testParseWorkspaceCommand() {
        testParseCommandFail("workspace my mail", msg: "ERROR: Unknown argument 'mail'", exitCode: 2)
        testParseCommandFail("workspace 'my mail'", msg: "ERROR: Whitespace characters are forbidden in workspace names", exitCode: 2)
        assertEquals(parseCommand("workspace").errorOrNil, "ERROR: Argument '(<workspace-name>|next|prev)' is mandatory")
        testParseSingleCommandSucc("workspace next", WorkspaceCmdArgs(target: .relative(.next)))
        testParseSingleCommandSucc("workspace --auto-back-and-forth W", WorkspaceCmdArgs(target: .direct(.parse("W").getOrDie()), autoBackAndForth: true))
        assertEquals(parseCommand("workspace --wrap-around W").errorOrNil, "--wrapAround requires using (next|prev) argument")
        assertEquals(parseCommand("workspace --auto-back-and-forth next").errorOrNil, "--auto-back-and-forth is incompatible with (next|prev)")
        testParseSingleCommandSucc("workspace next --wrap-around", WorkspaceCmdArgs(target: .relative(.next), wrapAround: true))
        assertEquals(parseCommand("workspace --stdin foo").errorOrNil, "--stdin and --no-stdin require using (next|prev) argument")
        testParseSingleCommandSucc("workspace --stdin next", WorkspaceCmdArgs(target: .relative(.next)).copy(\.commonState.explicitStdinFlag, true))
        testParseSingleCommandSucc("workspace --no-stdin next", WorkspaceCmdArgs(target: .relative(.next)).copy(\.commonState.explicitStdinFlag, false))
    }

    func testParseDashDash() {
        testParseSingleCommandSucc("workspace -- foo", WorkspaceCmdArgs(target: .direct(.parse("foo").getOrDie())))
        assertEquals(parseCommand("workspace -- next").errorOrNil, "ERROR: 'next' is a reserved workspace name")
        assertEquals(parseCommand("workspace --").errorOrNil, "ERROR: Argument \'(<workspace-name>|next|prev)\' is mandatory")
        testParseSingleCommandSucc(
            "workspace --auto-back-and-forth -- foo",
            WorkspaceCmdArgs(target: .direct(.parse("foo").getOrDie()), autoBackAndForth: true),
        )
        assertEquals(parseCommand("workspace -- foo --fail-if-noop").errorOrNil, "ERROR: Unknown argument '--fail-if-noop'")
        assertEquals(parseCommand("workspace -- --help").errorOrNil, "ERROR: Workspace names starting with dash are disallowed")
    }

    func testDirect_focusDifferentWorkspace() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("workspace b").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, [])
        assertEquals(focus.workspace.name, "b")
    }

    func testDirect_alreadyFocused_succWithMessage() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("workspace a").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["Workspace 'a' is already focused. Tip: use --fail-if-noop to exit with non-zero code"])
        assertEquals(focus.workspace.name, "a")
    }

    func testDirect_alreadyFocused_failIfNoop_fails() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("workspace --fail-if-noop a").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, [])
        assertEquals(focus.workspace.name, "a")
    }

    func testAutoBackAndForth_alreadyFocused_focusesPrev() async {
        // Make "b" alive so it can be focused as the back-and-forth target.
        _ = Workspace.get(byName: "b")
        assertTrue(Workspace.get(byName: "a").focusWorkspace())
        _prevFocusedWorkspaceName = "b"

        let result = await parseCommand("workspace --auto-back-and-forth a").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.workspace.name, "b")
    }

    func testAutoBackAndForth_alreadyFocused_noPrev_fails() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())
        // _prevFocusedWorkspaceName is nil from setUp — WorkspaceBackAndForthCommand has nothing to focus.

        let result = await parseCommand("workspace --auto-back-and-forth a").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(focus.workspace.name, "a")
    }

    func testAutoBackAndForth_differentWorkspace_focusesTarget() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())
        // --auto-back-and-forth only kicks in when the target equals the focused workspace.
        // Otherwise it's a regular direct focus.
        _prevFocusedWorkspaceName = "c" // should be ignored

        let result = await parseCommand("workspace --auto-back-and-forth b").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.workspace.name, "b")
    }

    func testRelativeNext_stdin() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("workspace --stdin next").cmdOrDie.run(.defaultEnv, CmdStdin("a\nb\nc\n"))
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.workspace.name, "b")
    }

    func testRelativePrev_stdin() async {
        assertTrue(Workspace.get(byName: "b").focusWorkspace())

        let result = await parseCommand("workspace --stdin prev").cmdOrDie.run(.defaultEnv, CmdStdin("a\nb\nc\n"))
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.workspace.name, "a")
    }

    func testRelativeNext_wrapAround_stdin() async {
        assertTrue(Workspace.get(byName: "c").focusWorkspace())

        let result = await parseCommand("workspace --wrap-around --stdin next").cmdOrDie.run(.defaultEnv, CmdStdin("a\nb\nc\n"))
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.workspace.name, "a")
    }

    func testRelativePrev_wrapAround_stdin() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("workspace --wrap-around --stdin prev").cmdOrDie.run(.defaultEnv, CmdStdin("a\nb\nc\n"))
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.workspace.name, "c")
    }

    func testRelativeNext_noNext_failsWithoutWrap() async {
        assertTrue(Workspace.get(byName: "c").focusWorkspace())

        // "c" is the last workspace in the stdin list, no wrap-around → cannot resolve next.
        let result = await parseCommand("workspace --stdin next").cmdOrDie.run(.defaultEnv, CmdStdin("a\nb\nc\n"))
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(focus.workspace.name, "c")
    }

    func testRelativePrev_noPrev_failsWithoutWrap() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("workspace --stdin prev").cmdOrDie.run(.defaultEnv, CmdStdin("a\nb\nc\n"))
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(focus.workspace.name, "a")
    }

    func testRelativeNext_emptyStdin_fails() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("workspace --stdin next").cmdOrDie.run(.defaultEnv, CmdStdin(""))
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(focus.workspace.name, "a")
    }

    func testRelativeNext_currentNotInStdin() async {
        // When current workspace isn't in the stdin list, index defaults to 0, so `next` lands on index 1.
        assertTrue(Workspace.get(byName: "z").focusWorkspace())

        let result = await parseCommand("workspace --stdin next").cmdOrDie.run(.defaultEnv, CmdStdin("a\nb\nc\n"))
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.workspace.name, "a")
    }

    func testRelativeNext_noStdin_picksFromAllWorkspaces() async {
        // Without --stdin, getNextPrevWorkspace pulls from Workspace.all on the focused monitor.
        _ = Workspace.get(byName: "b") // keep "b" alive in the registry
        _ = Workspace.get(byName: "c")
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        let result = await parseCommand("workspace next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.workspace.name, "b")
    }
}
