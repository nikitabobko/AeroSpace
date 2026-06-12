@testable import AppBundle
import Common
import XCTest

@MainActor
final class MoveNodeToWorkspaceCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseCommandSucc("move-node-to-workspace next", MoveNodeToWorkspaceCmdArgs(target: .relative(.next)))
        assertEquals(parseCommand("move-node-to-workspace --fail-if-noop next").errorOrNil, "--fail-if-noop is incompatible with (next|prev)")
        assertEquals(parseCommand("move-node-to-workspace --stdin foo").errorOrNil, "--stdin and --no-stdin require using (next|prev) argument")
        testParseCommandSucc("move-node-to-workspace --stdin next", MoveNodeToWorkspaceCmdArgs(target: .relative(.next)).copy(\.explicitStdinFlag, true))
        testParseCommandSucc("move-node-to-workspace --no-stdin next", MoveNodeToWorkspaceCmdArgs(target: .relative(.next)).copy(\.explicitStdinFlag, false))
    }

    func testSimple() async throws {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b")).run(.defaultEnv, .emptyStdin)
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        assertEquals((Workspace.get(byName: "b").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testEmptyWorkspaceSubject() async throws {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b")).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "a")
    }

    func testAnotherWindowSubject() async throws {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            _ = TestWindow.new(id: 2, parent: $0).focusWindow()
        }

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b")).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testPreserveFloatingLayout() async throws {
        let workspaceA = Workspace.get(byName: "a").apply {
            assertTrue(TestWindow.new(id: 1, parent: $0.floatingWindowsContainer).focusWindow())
        }

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b")).run(.defaultEnv, .emptyStdin)
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        assertEquals((Workspace.get(byName: "b").floatingWindowsContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testSummonWindow() async throws {
        let workspaceA = Workspace.get(byName: "a").apply {
            $0.rootTilingContainer.apply {
                _ = TestWindow.new(id: 1, parent: $0).focusWindow()
            }
        }
        Workspace.get(byName: "b").rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.workspace, workspaceA)

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "a").copy(\.windowId, 2))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(focus.workspace, workspaceA)
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(Workspace.get(byName: "b").rootTilingContainer.children.count, 0)
        assertEquals(workspaceA.rootTilingContainer.children.count, 2)
    }

    func testNoWindowIsFocused() async throws {
        let result = try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b"))
            .run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [noWindowIsFocused])
    }

    func testFailIfNoop_succWithMessage() async throws {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        let result = try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "a"))
            .run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr.count, 1)
        assertTrue(result.stderr.first?.contains("already belongs to workspace 'a'") == true)
        assertEquals(Workspace.get(byName: "a").rootTilingContainer.children.count, 1)
    }

    func testFailIfNoop_fails() async throws {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        let result = try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "a").copy(\.failIfNoop, true))
            .run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [])
        assertEquals(Workspace.get(byName: "a").rootTilingContainer.children.count, 1)
    }

    func testFocusFollowsWindow() async throws {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }
        assertEquals(focus.workspace.name, "a")

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b").copy(\.focusFollowsWindow, true))
            .run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "b")
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertTrue(workspaceA.isEffectivelyEmpty)
    }

    func testRelativeNext() async throws {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }
        // Make "b" alive so the relative target has somewhere to go
        _ = Workspace.get(byName: "b").rootTilingContainer

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(target: .relative(.next)))
            .run(.defaultEnv, .emptyStdin)

        assertTrue(Workspace.get(byName: "a").isEffectivelyEmpty)
        assertEquals((Workspace.get(byName: "b").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testRelativeNoNextWorkspace_failsToResolve() async throws {
        // "a" is the only alive workspace besides the focused one. Calling `prev` from the first workspace without
        // wrap-around has nowhere to go.
        Workspace.get(byName: "a").rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        let result = try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(target: .relative(.prev)))
            .run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Can't resolve next or prev workspace"])
        // Window untouched
        assertEquals((Workspace.get(byName: "a").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testRelativeWrapAround() async throws {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        // Stdin-controlled list keeps the wrap behavior independent of which workspaces happen to be alive.
        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(target: .relative(.prev), wrapAround: true).copy(\.explicitStdinFlag, true))
            .run(.defaultEnv, CmdStdin("a\nb\n"))

        assertTrue(Workspace.get(byName: "a").isEffectivelyEmpty)
        assertEquals((Workspace.get(byName: "b").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testRelativeStdin() async throws {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        // Workspaces listed via stdin: focus is "a", next should be the workspace listed after it.
        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(target: .relative(.next)).copy(\.explicitStdinFlag, true))
            .run(.defaultEnv, CmdStdin("a\nx\ny\n"))

        assertTrue(Workspace.get(byName: "a").isEffectivelyEmpty)
        assertEquals((Workspace.get(byName: "x").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }
}
