@testable import AppBundle
import Common
import XCTest

@MainActor
final class StickyCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseCommandSucc("sticky", StickyCmdArgs(rawArgs: []))
        testParseCommandSucc("sticky on", StickyCmdArgs(rawArgs: []).copy(\.toggle, .on))
        testParseCommandSucc("sticky off", StickyCmdArgs(rawArgs: []).copy(\.toggle, .off))
        testParseCommandSucc("sticky --window-id 42 off", StickyCmdArgs(rawArgs: []).copy(\.windowId, 42).copy(\.toggle, .off))
        testParseCommandSucc("sticky --fail-if-noop on", StickyCmdArgs(rawArgs: []).copy(\.failIfNoop, true).copy(\.toggle, .on))
        assertEquals(parseCommand("sticky --fail-if-noop").errorOrNil, "--fail-if-noop requires 'on' or 'off' argument")
    }

    func testToggleOnOffAndNoop() async throws {
        var window: TestWindow!
        Workspace.get(byName: "a").rootTilingContainer.apply {
            window = TestWindow.new(id: 1, parent: $0)
        }
        _ = window.focusWindow()

        try await StickyCommand(args: StickyCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        assertEquals(window.isSticky, true)

        try await StickyCommand(args: StickyCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        assertEquals(window.isSticky, false)

        try await parseCommand("sticky on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.isSticky, true)

        let alreadySticky = try await parseCommand("sticky on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(alreadySticky.exitCode.rawValue, 0)
        assertEquals(alreadySticky.stderr, ["Already sticky. Tip: use --fail-if-noop to exit with non-zero code"])

        let failIfNoop = try await parseCommand("sticky --fail-if-noop on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(failIfNoop.exitCode.rawValue, 2)

        try await parseCommand("sticky off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.isSticky, false)
    }

    func testWindowId() async throws {
        var window1: TestWindow!
        var window2: TestWindow!
        Workspace.get(byName: "a").rootTilingContainer.apply {
            window1 = TestWindow.new(id: 1, parent: $0)
            window2 = TestWindow.new(id: 2, parent: $0)
        }
        _ = window1.focusWindow()

        try await parseCommand("sticky --window-id 2 on").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(window1.isSticky, false)
        assertEquals(window2.isSticky, true)
    }

    func testStickyWindowUsesVisibleWorkspaceWhenHomeWorkspaceIsHidden() {
        let workspaceA = Workspace.get(byName: "a")
        let workspaceB = Workspace.get(byName: "b")
        var window: TestWindow!
        workspaceA.rootTilingContainer.apply {
            window = TestWindow.new(id: 1, parent: $0)
        }
        window.isSticky = true

        check(workspaceB.focusWorkspace())

        assertEquals(window.nodeWorkspace, workspaceA)
        assertEquals(window.visualWorkspace, workspaceB)
        assertEquals(window.isVisuallyOn(workspace: workspaceB), true)
        assertEquals(window.isVisuallyOn(workspace: workspaceA), false)
        assertEquals(windowsVisuallyOnWorkspace(workspaceB), [window])
    }

    func testNonStickyWindowStaysVisuallyOnItsHomeWorkspaceWhenHidden() {
        let workspaceA = Workspace.get(byName: "a")
        let workspaceB = Workspace.get(byName: "b")
        var window: TestWindow!
        workspaceA.rootTilingContainer.apply {
            window = TestWindow.new(id: 1, parent: $0)
        }

        check(workspaceB.focusWorkspace())

        assertEquals(window.nodeWorkspace, workspaceA)
        assertEquals(window.visualWorkspace, workspaceA)
        assertEquals(window.shouldStayVisibleWhenOwningWorkspaceIsHidden, false)
    }

    func testListVisibleAndMonitorWindowsIncludeStickyWindowsWithoutDuplication() async throws {
        let workspaceA = Workspace.get(byName: "a")
        let workspaceB = Workspace.get(byName: "b")
        workspaceA.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0).isSticky = true
        }
        workspaceB.rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
        }
        check(workspaceB.focusWorkspace())

        let result = try await parseCommand("list-windows --workspace visible --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.stdout.toSet(), ["1", "2"])

        let monitorResult = try await parseCommand("list-windows --monitor all --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(monitorResult.stdout.toSet(), ["1", "2"])
        assertEquals(monitorResult.stdout.count, 2)
    }

    func testStickyWindowInVisibleHomeWorkspaceIsNotDuplicatedInListWindows() async throws {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0).isSticky = true
        }

        let result = try await parseCommand("list-windows --workspace visible --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.stdout, ["1"])
    }

    func testWindowIsStickyFormatVar() async throws {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0).isSticky = true
            TestWindow.new(id: 2, parent: $0)
        }
        check(workspaceA.focusWorkspace())

        let result = try await parseCommand("list-windows --workspace visible --format '%{window-id} %{window-is-sticky}'").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.stdout.toSet(), ["1 true", "2 false"])
    }

    func testStickyOnAutoFloatsTilingWindow() async throws {
        let workspaceA = Workspace.get(byName: "a")
        var window: TestWindow!
        workspaceA.rootTilingContainer.apply {
            window = TestWindow.new(id: 1, parent: $0)
        }
        _ = window.focusWindow()

        assertTrue(window.isFloating == false)

        try await parseCommand("sticky on").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(window.isSticky, true)
        assertTrue(window.isFloating)
        assertEquals(window.nodeWorkspace, workspaceA)
    }

    func testStickyOnPreservesAlreadyFloatingWindow() async throws {
        let workspaceA = Workspace.get(byName: "a")
        var window: TestWindow!
        window = TestWindow.new(id: 1, parent: workspaceA) // Direct child of workspace = floating
        _ = window.focusWindow()

        assertTrue(window.isFloating)

        try await parseCommand("sticky on").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(window.isSticky, true)
        assertTrue(window.isFloating)
        assertEquals(window.nodeWorkspace, workspaceA)
    }

    func testStickyOffDoesNotReTile() async throws {
        let workspaceA = Workspace.get(byName: "a")
        var window: TestWindow!
        workspaceA.rootTilingContainer.apply {
            window = TestWindow.new(id: 1, parent: $0)
        }
        _ = window.focusWindow()

        try await parseCommand("sticky on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertTrue(window.isFloating)

        try await parseCommand("sticky off").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(window.isSticky, false)
        assertTrue(window.isFloating) // Still floating, not auto-re-tiled
    }

    func testStickyWindowPositioningOnWorkspaceSwitch() {
        let workspaceA = Workspace.get(byName: "a")
        let workspaceB = Workspace.get(byName: "b")
        var window: TestWindow!
        workspaceA.rootTilingContainer.apply {
            window = TestWindow.new(id: 1, parent: $0)
        }
        window.isSticky = true
        // Simulate auto-float: sticky on would have made it floating
        window.bindAsFloatingWindow(to: workspaceA)

        check(workspaceB.focusWorkspace())

        // Sticky floating window should be visually on workspace B
        assertEquals(window.nodeWorkspace, workspaceA)
        assertEquals(window.visualWorkspace, workspaceB)
        assertEquals(windowsVisuallyOnWorkspace(workspaceB).contains(window), true)
    }

    func testMoveNodeToWorkspacePreservesStickyState() async throws {
        let workspaceA = Workspace.get(byName: "a")
        let workspaceB = Workspace.get(byName: "b")
        var window: TestWindow!
        workspaceA.rootTilingContainer.apply {
            window = TestWindow.new(id: 1, parent: $0)
        }
        window.isSticky = true
        _ = window.focusWindow()

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b")).run(.defaultEnv, .emptyStdin)

        assertEquals(window.isSticky, true)
        assertEquals(window.nodeWorkspace, workspaceB)
    }
}
