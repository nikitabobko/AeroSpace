@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct StickyCommandTest {
    init() { setUpWorkspacesForTests() }

    @Test func testParse() {
        testParseSingleCommandSucc("sticky", StickyCmdArgs(rawArgs: []))
        testParseSingleCommandSucc("sticky on", StickyCmdArgs(rawArgs: []).with(\.toggle, .on))
        testParseSingleCommandSucc("sticky off", StickyCmdArgs(rawArgs: []).with(\.toggle, .off))
        testParseSingleCommandSucc("sticky --window-id 42 off", StickyCmdArgs(rawArgs: []).with(\.windowId, 42).with(\.toggle, .off))
        testParseSingleCommandSucc("sticky --fail-if-noop on", StickyCmdArgs(rawArgs: []).with(\.failIfNoop, true).with(\.toggle, .on))
        assertEquals(parseCommand("sticky --fail-if-noop").errorOrNil, "--fail-if-noop requires 'on' or 'off' argument")
    }

    @Test func testToggleOnOffAndNoop() async {
        var window: TestWindow!
        Workspace.get(byName: "a").rootTilingContainer.apply {
            window = TestWindow.new(id: 1, parent: $0)
        }
        _ = window.focusWindow()

        await StickyCommand(args: StickyCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        assertEquals(window.isSticky, true)

        await StickyCommand(args: StickyCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        assertEquals(window.isSticky, false)

        await parseCommand("sticky on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.isSticky, true)

        let alreadySticky = await parseCommand("sticky on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(alreadySticky.exitCode.rawValue, 0)
        assertEquals(alreadySticky.stderr, ["Already sticky. Tip: use --fail-if-noop to exit with non-zero code"])

        let failIfNoop = await parseCommand("sticky --fail-if-noop on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(failIfNoop.exitCode.rawValue, 2)

        await parseCommand("sticky off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.isSticky, false)
    }

    @Test func testWindowId() async {
        var window1: TestWindow!
        var window2: TestWindow!
        Workspace.get(byName: "a").rootTilingContainer.apply {
            window1 = TestWindow.new(id: 1, parent: $0)
            window2 = TestWindow.new(id: 2, parent: $0)
        }
        _ = window1.focusWindow()

        await parseCommand("sticky --window-id 2 on").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(window1.isSticky, false)
        assertEquals(window2.isSticky, true)
    }

    @Test func testStickyWindowUsesVisibleWorkspaceWhenHomeWorkspaceIsHidden() {
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

    @Test func testNonStickyWindowStaysVisuallyOnItsHomeWorkspaceWhenHidden() {
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

    @Test func testListVisibleAndMonitorWindowsIncludeStickyWindowsWithoutDuplication() async {
        let workspaceA = Workspace.get(byName: "a")
        let workspaceB = Workspace.get(byName: "b")
        workspaceA.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0).isSticky = true
        }
        workspaceB.rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
        }
        check(workspaceB.focusWorkspace())

        let result = await parseCommand("list-windows --workspace visible --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.stdout.toSet(), ["1", "2"])

        let monitorResult = await parseCommand("list-windows --monitor all --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(monitorResult.stdout.toSet(), ["1", "2"])
        assertEquals(monitorResult.stdout.count, 2)
    }

    @Test func testStickyWindowInVisibleHomeWorkspaceIsNotDuplicatedInListWindows() async {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0).isSticky = true
        }

        let result = await parseCommand("list-windows --workspace visible --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.stdout, ["1"])
    }

    @Test func testWindowIsStickyFormatVar() async {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0).isSticky = true
            TestWindow.new(id: 2, parent: $0)
        }
        check(workspaceA.focusWorkspace())

        let result = await parseCommand("list-windows --workspace visible --format '%{window-id} %{window-is-sticky}'").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.stdout.toSet(), ["1 true", "2 false"])
    }

    @Test func testStickyOnAutoFloatsTilingWindow() async {
        let workspaceA = Workspace.get(byName: "a")
        var window: TestWindow!
        workspaceA.rootTilingContainer.apply {
            window = TestWindow.new(id: 1, parent: $0)
        }
        _ = window.focusWindow()

        assertTrue(window.isFloating == false)

        await parseCommand("sticky on").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(window.isSticky, true)
        assertTrue(window.isFloating)
        assertEquals(window.nodeWorkspace, workspaceA)
    }

    @Test func testStickyOnPreservesAlreadyFloatingWindow() async {
        let workspaceA = Workspace.get(byName: "a")
        var window: TestWindow!
        window = TestWindow.new(id: 1, parent: workspaceA.floatingWindowsContainer) // Direct child of workspace = floating
        _ = window.focusWindow()

        assertTrue(window.isFloating)

        await parseCommand("sticky on").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(window.isSticky, true)
        assertTrue(window.isFloating)
        assertEquals(window.nodeWorkspace, workspaceA)
    }

    @Test func testStickyOffDoesNotReTile() async {
        let workspaceA = Workspace.get(byName: "a")
        var window: TestWindow!
        workspaceA.rootTilingContainer.apply {
            window = TestWindow.new(id: 1, parent: $0)
        }
        _ = window.focusWindow()

        await parseCommand("sticky on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertTrue(window.isFloating)

        await parseCommand("sticky off").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(window.isSticky, false)
        assertTrue(window.isFloating) // Still floating, not auto-re-tiled
    }

    @Test func testStickyWindowPositioningOnWorkspaceSwitch() {
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

    @Test func testMoveNodeToWorkspacePreservesStickyState() async {
        let workspaceA = Workspace.get(byName: "a")
        let workspaceB = Workspace.get(byName: "b")
        var window: TestWindow!
        workspaceA.rootTilingContainer.apply {
            window = TestWindow.new(id: 1, parent: $0)
        }
        window.isSticky = true
        _ = window.focusWindow()

        await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b")).run(.defaultEnv, .emptyStdin)

        assertEquals(window.isSticky, true)
        assertEquals(window.nodeWorkspace, workspaceB)
    }
}
