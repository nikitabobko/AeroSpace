@testable import AppBundle
import Common
import XCTest

@MainActor
final class ListWorkspacesTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        assertNotNil(parseCommand("list-workspaces --all").cmdOrNil)
        assertNil(parseCommand("list-workspaces --all --visible").cmdOrNil)
        assertNil(parseCommand("list-workspaces --focused --visible").cmdOrNil)
        assertNil(parseCommand("list-workspaces --focused --all").cmdOrNil)
        assertNil(parseCommand("list-workspaces --visible").cmdOrNil)
        assertNotNil(parseCommand("list-workspaces --visible --monitor 2").cmdOrNil)
        assertNotNil(parseCommand("list-workspaces --monitor focused").cmdOrNil)
        assertNil(parseCommand("list-workspaces --focused --monitor 2").cmdOrNil)
        assertNotNil(parseCommand("list-workspaces --all --format %{workspace}").cmdOrNil)
        assertEquals(parseCommand("list-workspaces --all --format %{workspace} --count").errorOrNil, "ERROR: Conflicting options: --count, --format")
        assertEquals(parseCommand("list-workspaces --empty").errorOrNil, "Mandatory option is not specified (--all|--focused|--monitor)")
        assertEquals(parseCommand("list-workspaces --all --focused --monitor mouse").errorOrNil, "ERROR: Conflicting options: --all, --focused, --monitor")
    }

    func testRunAll() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        TestWindow.new(id: 2, parent: Workspace.get(byName: "b").rootTilingContainer)
        let result = await parseCommand("list-workspaces --all").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        // Initial focused workspace "setUpWorkspacesForTests" is included; sort uses logical segments.
        assertEquals(result.stdout, ["a", "b", "setUpWorkspacesForTests"])
    }

    func testRunVisible() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        let result = await parseCommand("list-workspaces --monitor all --visible").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        // Only the focused workspace is visible after setUp on the single test monitor.
        assertEquals(result.stdout, ["setUpWorkspacesForTests"])
    }

    func testRunInvisible() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        TestWindow.new(id: 2, parent: Workspace.get(byName: "b").rootTilingContainer)
        let result = await parseCommand("list-workspaces --monitor all --visible no").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["a", "b"])
    }

    func testRunEmpty() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        _ = Workspace.get(byName: "b") // empty (no windows)
        let result = await parseCommand("list-workspaces --monitor all --empty").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["b", "setUpWorkspacesForTests"])
    }

    func testRunNonEmpty() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        _ = Workspace.get(byName: "b") // empty
        let result = await parseCommand("list-workspaces --monitor all --empty no").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["a"])
    }

    func testRunFocusedAlias() async {
        // The initial focused workspace is "setUpWorkspacesForTests" (visible on the focused monitor).
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        let result = await parseCommand("list-workspaces --focused").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        // --focused expands to --monitor focused --visible true.
        assertEquals(result.stdout, ["setUpWorkspacesForTests"])
    }

    func testRunMonitorFocused() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        let result = await parseCommand("list-workspaces --monitor focused").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        // All workspaces default to the main (focused) monitor in tests.
        assertEquals(result.stdout, ["a", "setUpWorkspacesForTests"])
    }

    func testRunInvalidMonitor() async {
        let result = await parseCommand("list-workspaces --monitor 99").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["Invalid monitor ID: 99"])
    }

    func testRunCount() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        TestWindow.new(id: 2, parent: Workspace.get(byName: "b").rootTilingContainer)
        let result = await parseCommand("list-workspaces --all --count").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["3"])
    }

    func testRunJson() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        let result = await parseCommand("list-workspaces --all --format '%{workspace}' --json").cmdOrDie.run(.defaultEnv, .emptyStdin)
        let expected = JSONEncoder.aeroSpaceDefault.encodeToString([
            ["workspace": "a"],
            ["workspace": "setUpWorkspacesForTests"],
        ])
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [expected])
    }
}
