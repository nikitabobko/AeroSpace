@testable import AppBundle
import Common
import XCTest

@MainActor
final class MoveNodeToWorkspaceCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseSingleCommandSucc("move-node-to-workspace next", MoveNodeToWorkspaceCmdArgs(target: .relative(.next)))
        assertEquals(parseCommand("move-node-to-workspace --fail-if-noop next").errorOrNil, "--fail-if-noop is incompatible with (next|prev)")
        assertEquals(parseCommand("move-node-to-workspace --stdin foo").errorOrNil, "--stdin and --no-stdin require using (next|prev) argument")
        testParseSingleCommandSucc("move-node-to-workspace --stdin next", MoveNodeToWorkspaceCmdArgs(target: .relative(.next)).copy(\.commonState.explicitStdinFlag, true))
        testParseSingleCommandSucc("move-node-to-workspace --no-stdin next", MoveNodeToWorkspaceCmdArgs(target: .relative(.next)).copy(\.commonState.explicitStdinFlag, false))
    }

    func testParseDashDash() {
        testParseSingleCommandSucc("move-node-to-workspace -- foo", MoveNodeToWorkspaceCmdArgs(workspace: "foo"))
        assertEquals(parseCommand("move-node-to-workspace -- prev").errorOrNil, "ERROR: 'prev' is a reserved workspace name")
        assertEquals(parseCommand("move-node-to-workspace --").errorOrNil, "ERROR: Argument \'(<workspace-name>|next|prev)\' is mandatory")
        testParseSingleCommandSucc(
            "move-node-to-workspace --focus-follows-window -- foo",
            MoveNodeToWorkspaceCmdArgs(workspace: "foo").copy(\.focusFollowsWindow, true),
        )
    }

    func testSimple() async {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        await parseCommand("move-node-to-workspace b").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        assertEquals((Workspace.get(byName: "b").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testEmptyWorkspaceSubject() async {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        await parseCommand("move-node-to-workspace b").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "a")
    }

    func testAnotherWindowSubject() async {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            _ = TestWindow.new(id: 2, parent: $0).focusWindow()
        }

        await parseCommand("move-node-to-workspace b").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testPreserveFloatingLayout() async {
        let workspaceA = Workspace.get(byName: "a").apply {
            assertTrue(TestWindow.new(id: 1, parent: $0.floatingWindowsContainer).focusWindow())
        }

        await parseCommand("move-node-to-workspace b").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        assertEquals((Workspace.get(byName: "b").floatingWindowsContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testSummonWindow() async {
        let workspaceA = Workspace.get(byName: "a").apply {
            $0.rootTilingContainer.apply {
                _ = TestWindow.new(id: 1, parent: $0).focusWindow()
            }
        }
        Workspace.get(byName: "b").rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.workspace, workspaceA)

        await parseCommand("move-node-to-workspace --window-id 2 a").cmdOrDie
            .run(.defaultEnv, .emptyStdin)

        assertEquals(focus.workspace, workspaceA)
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(Workspace.get(byName: "b").rootTilingContainer.children.count, 0)
        assertEquals(workspaceA.rootTilingContainer.children.count, 2)
    }

    func testNoWindowIsFocused() async {
        let result = await parseCommand("move-node-to-workspace b").cmdOrDie
            .run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [noWindowIsFocused])
    }

    func testFailIfNoop_succWithMessage() async {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        let result = await parseCommand("move-node-to-workspace a").cmdOrDie
            .run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr.count, 1)
        assertTrue(result.stderr.first?.contains("already belongs to workspace 'a'") == true)
        assertEquals(Workspace.get(byName: "a").rootTilingContainer.children.count, 1)
    }

    func testFailIfNoop_fails() async {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        let result = await parseCommand("move-node-to-workspace --fail-if-noop a").cmdOrDie
            .run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [])
        assertEquals(Workspace.get(byName: "a").rootTilingContainer.children.count, 1)
    }

    func testFocusFollowsWindow() async {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }
        assertEquals(focus.workspace.name, "a")

        await parseCommand("move-node-to-workspace --focus-follows-window b").cmdOrDie
            .run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "b")
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertTrue(workspaceA.isEffectivelyEmpty)
    }

    func testRelativeNext() async {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }
        // Make "b" alive so the relative target has somewhere to go
        _ = Workspace.get(byName: "b").rootTilingContainer

        await parseCommand("move-node-to-workspace next").cmdOrDie
            .run(.defaultEnv, .emptyStdin)

        assertTrue(Workspace.get(byName: "a").isEffectivelyEmpty)
        assertEquals((Workspace.get(byName: "b").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testRelativeNoNextWorkspace_failsToResolve() async {
        // "a" is the only alive workspace besides the focused one. Calling `prev` from the first workspace without
        // wrap-around has nowhere to go.
        Workspace.get(byName: "a").rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        let result = await parseCommand("move-node-to-workspace prev").cmdOrDie
            .run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Rached the beginning of the supplied workspaces list"])
        // Window untouched
        assertEquals((Workspace.get(byName: "a").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testRelativeWrapAround() async {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        // Stdin-controlled list keeps the wrap behavior independent of which workspaces happen to be alive.
        await parseCommand("move-node-to-workspace --wrap-around --stdin prev").cmdOrDie
            .run(.defaultEnv, CmdStdin("a\nb\n"))

        assertTrue(Workspace.get(byName: "a").isEffectivelyEmpty)
        assertEquals((Workspace.get(byName: "b").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testRelativeStdin() async {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        // Workspaces listed via stdin: focus is "a", next should be the workspace listed after it.
        await parseCommand("move-node-to-workspace --stdin next").cmdOrDie
            .run(.defaultEnv, CmdStdin("a\nx\ny\n"))

        assertTrue(Workspace.get(byName: "a").isEffectivelyEmpty)
        assertEquals((Workspace.get(byName: "x").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }
}
