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
        testParseSingleCommandSucc("move-node-to-monitor --parent next", MoveNodeToMonitorCmdArgs(target: .relative(.next)).copy(\.parent, true))
        testParseSingleCommandSucc(
            "move-node-to-monitor --parent --fail-if-noop main",
            MoveNodeToMonitorCmdArgs(target: .patterns([.main])).copy(\.parent, true).copy(\.failIfNoop, true),
        )
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

    func testMoveParent_failIfNoop() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
                TestWindow.new(id: 3, parent: $0)
            }
        }

        // The only monitor in tests is the main monitor
        let result = await parseCommand("move-node-to-monitor --parent --fail-if-noop main").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [])
        assertEquals(
            root.layoutDescription,
            .h_tiles([
                .window(1),
                .v_tiles([.window(2), .window(3)]),
            ]),
        )
    }

    func testMoveParent_failsIfParentIsRootContainer() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        let result = await parseCommand("move-node-to-monitor --parent main").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Can't move the parent container of window 1: it's the root container of the workspace"])
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))
    }
}
