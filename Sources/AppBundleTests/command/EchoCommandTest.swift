@testable import AppBundle
import Common
import XCTest

@MainActor
final class EchoCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseSingleCommandSucc(
            "echo -- foo",
            EchoCmdArgs(rawArgs: []).copy(\.args, .initialized([[.literal("foo")]])),
        )
        testParseSingleCommandSucc(
            "echo -- foo bar",
            EchoCmdArgs(rawArgs: []).copy(\.args, .initialized([[.literal("foo")], [.literal("bar")]])),
        )
        testParseSingleCommandSucc(
            "echo --stderr -- foo",
            EchoCmdArgs(rawArgs: [])
                .copy(\.args, .initialized([[.literal("foo")]]))
                .copy(\.isStderr, true),
        )
        testParseSingleCommandSucc(
            "echo -- '%{window-id}'",
            EchoCmdArgs(rawArgs: []).copy(\.args, .initialized([[.interVar(.formatVar(.window(.windowId)))]])),
        )
        testParseSingleCommandSucc(
            "echo -- 'id: %{window-id}'",
            EchoCmdArgs(rawArgs: []).copy(\.args, .initialized([[.literal("id: "), .interVar(.formatVar(.window(.windowId)))]])),
        )
        testParseSingleCommandSucc(
            "echo -- --stderr",
            EchoCmdArgs(rawArgs: []).copy(\.args, .initialized([[.literal("--stderr")]])),
        )
        testParseSingleCommandSucc(
            "echo -- -h",
            EchoCmdArgs(rawArgs: []).copy(\.args, .initialized([[.literal("-h")]])),
        )

        testParseCommandFail("echo", msg: "ERROR: Argument '--' is mandatory\nERROR: Argument '<string>' is mandatory", exitCode: 2)
        testParseCommandFail("echo --", msg: "ERROR: Argument '<string>' is mandatory", exitCode: 2)
        testParseCommandFail("echo foo", msg: "ERROR: Expected: --. Got: 'foo'", exitCode: 2)
        testParseCommandFail("echo --stderr foo", msg: "ERROR: Expected: --. Got: 'foo'", exitCode: 2)
        testParseCommandFail("echo -- %{foo}", msg: "ERROR: Can't parse 'foo'.\n       Possible values: (window-id|window-is-fullscreen|window-title|window-layout|window-parent-container-layout|workspace|workspace-is-focused|workspace-is-visible|workspace-root-container-layout|app-bundle-id|app-name|app-pid|app-exec-path|app-bundle-path|monitor-id|monitor-appkit-nsscreen-screens-id|monitor-name|monitor-is-main|right-padding|newline|tab)", exitCode: 2)

        testParseCommandHelp("echo -h")
        testParseCommandHelp("echo --help")
    }

    func testRunPlainNoWindow() async {
        assertEquals(Workspace.get(byName: name).focusWorkspace(), true)
        let result = await parseCommand("echo -- foo").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["foo"])
    }

    func testRunMultipleArgs() async {
        assertEquals(Workspace.get(byName: name).focusWorkspace(), true)
        let result = await parseCommand("echo -- foo bar baz").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["foo", "bar", "baz"])
    }

    func testRunStderr() async {
        assertEquals(Workspace.get(byName: name).focusWorkspace(), true)
        let result = await parseCommand("echo --stderr -- foo").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["foo"])
    }

    func testRunWindowInterpolation() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }
        let result = await parseCommand("echo -- '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["1"])
    }

    func testRunWindowInterpolationNoWindow() async {
        assertEquals(Workspace.get(byName: name).focusWorkspace(), true)
        let result = await parseCommand("echo -- '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, [noWindowIsFocused])
    }

    func testRunWorkspaceInterpolation() async {
        assertEquals(Workspace.get(byName: name).focusWorkspace(), true)
        let result = await parseCommand("echo -- '%{workspace}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, [name])
    }

    func testRunMixedLiteralAndInterpolation() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 42, parent: $0).focusWindow(), true)
        }
        let result = await parseCommand("echo -- 'id: %{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["id: 42"])
    }

    func testRunStderrWithInterpolation() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 5, parent: $0).focusWindow(), true)
        }
        let result = await parseCommand("echo --stderr -- '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["5"])
    }
}
