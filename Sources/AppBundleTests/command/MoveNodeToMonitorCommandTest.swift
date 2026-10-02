@testable import AppBundle
import Common
import XCTest

@MainActor
final class MoveNodeToMonitorCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseSingleCommandSucc("move-node-to-monitor next", MoveNodeToMonitorCmdArgs(target: .relative(.next)))
        testParseSingleCommandSucc("move-node-to-monitor --fail-if-noop main", MoveNodeToMonitorCmdArgs(target: .patterns([.main])).copy(\.failIfNoop, true))
        assertEquals(parseCommand("move-node-to-monitor --fail-if-noop next").errorOrNil, "--fail-if-noop is incompatible with (left|down|up|right|next|prev)")
        assertEquals(parseCommand("move-node-to-monitor --fail-if-noop left").errorOrNil, "--fail-if-noop is incompatible with (left|down|up|right|next|prev)")
    }

    func testParseDashDash() {
        testParseSingleCommandSucc("move-node-to-monitor -- next", MoveNodeToMonitorCmdArgs(target: .patterns([.pattern("next")!])))
        testParseSingleCommandSucc(
            "move-node-to-monitor -- main 2",
            MoveNodeToMonitorCmdArgs(target: .patterns([.main, .sequenceNumber(2)])),
        )
        testParseSingleCommandSucc(
            "move-node-to-monitor --fail-if-noop -- next",
            MoveNodeToMonitorCmdArgs(target: .patterns([.pattern("next")!])).copy(\.failIfNoop, true),
        )
        assertEquals(parseCommand("move-node-to-monitor --").errorOrNil, "ERROR: Argument \'(left|down|up|right|next|prev|<monitor-pattern>)\' is mandatory")
    }

    func testMoveNodeToMonitorInDirection() async {
        let monitors = setUpMonitorsForTests([
            Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
        ])
        let workspaceA = Workspace.get(byName: "a").apply {
            $0.rootTilingContainer.apply {
                assertTrue(TestWindow.new(id: 1, parent: $0).focusWindow())
                TestWindow.new(id: 2, parent: $0)
            }
        }
        let workspaceB = Workspace.get(byName: "b").apply {
            TestWindow.new(id: 3, parent: $0.rootTilingContainer)
        }
        assertTrue(monitors[1].setActiveWorkspace(workspaceB))

        let result = await parseCommand("move-node-to-monitor right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(workspaceA.rootTilingContainer.layoutDescription, .h_tiles([.window(2)]))
        // The window enters the monitor from the left side
        assertEquals(workspaceB.rootTilingContainer.layoutDescription, .h_tiles([.window(1), .window(3)]))
        assertEquals(focus.workspace, workspaceA)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testMoveNodeToMonitorInDirection_verticalMonitors() async {
        let monitors = setUpMonitorsForTests([
            Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            Rect(topLeftX: 0, topLeftY: 1080, width: 1920, height: 1080),
        ])
        let workspaceA = Workspace.get(byName: "a").apply {
            $0.rootTilingContainer.apply {
                assertTrue(TestWindow.new(id: 1, parent: $0).focusWindow())
                TestWindow.new(id: 2, parent: $0)
            }
        }
        let workspaceB = Workspace.get(byName: "b").apply {
            TestWindow.new(id: 3, parent: $0.rootTilingContainer)
        }
        assertTrue(monitors[1].setActiveWorkspace(workspaceB))

        let result = await parseCommand("move-node-to-monitor down").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(workspaceA.rootTilingContainer.layoutDescription, .h_tiles([.window(2)]))
        assertEquals(workspaceB.rootTilingContainer.layoutDescription, .h_tiles([.window(3), .window(1)]))
    }

    func testMoveNodeToMonitor_focusFollowsWindow() async {
        let monitors = setUpMonitorsForTests([
            Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
        ])
        let workspaceA = Workspace.get(byName: "a").apply {
            assertTrue(TestWindow.new(id: 1, parent: $0.rootTilingContainer).focusWindow())
        }
        let workspaceB = Workspace.get(byName: "b").apply {
            TestWindow.new(id: 2, parent: $0.rootTilingContainer)
        }
        assertTrue(monitors[1].setActiveWorkspace(workspaceB))

        await parseCommand("move-node-to-monitor --focus-follows-window next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertTrue(workspaceA.isEffectivelyEmpty)
        assertEquals(workspaceB.rootTilingContainer.layoutDescription, .h_tiles([.window(2), .window(1)]))
        assertEquals(focus.workspace, workspaceB)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testMoveNodeToMonitor_noMonitorInDirection() async {
        setUpMonitorsForTests([
            Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
        ])
        let workspaceA = Workspace.get(byName: "a").apply {
            assertTrue(TestWindow.new(id: 1, parent: $0.rootTilingContainer).focusWindow())
        }

        let result = await parseCommand("move-node-to-monitor left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["No monitors in direction left"])
        assertEquals(workspaceA.rootTilingContainer.layoutDescription, .h_tiles([.window(1)]))
    }
}
