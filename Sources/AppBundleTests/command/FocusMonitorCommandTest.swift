@testable import AppBundle
import Common
import XCTest

@MainActor
final class FocusMonitorCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        assertEquals(parseFocusMonitorTarget("focus-monitor next"), .relative(.next))
        assertEquals(parseFocusMonitorTarget("focus-monitor left"), .direction(.left))
        assertEquals(parseFocusMonitorTarget("focus-monitor main"), .patterns([.main]))
        assertEquals(parseCommand("focus-monitor --wrap-around main").errorOrNil, "--wrap-around is incompatible with <monitor-pattern> argument")
    }

    func testParseDashDash() {
        assertEquals(parseFocusMonitorTarget("focus-monitor -- next"), .patterns([.pattern("next")!]))
        assertEquals(parseFocusMonitorTarget("focus-monitor -- main 2"), .patterns([.main, .sequenceNumber(2)]))
        assertEquals(parseCommand("focus-monitor --").errorOrNil, "ERROR: Argument \'(left|down|up|right|next|prev|<monitor-pattern>)\' is mandatory")
    }

    func testFocusMonitorInDirection() async {
        let monitors = setUpMonitorsForTests([
            Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
        ])
        assertTrue(Workspace.get(byName: "a").focusWorkspace())
        assertTrue(monitors[1].setActiveWorkspace(Workspace.get(byName: "b")))

        await parseCommand("focus-monitor right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "b")

        await parseCommand("focus-monitor left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "a")
    }

    func testFocusMonitorInDirection_noMonitorInDirection() async {
        let monitors = setUpMonitorsForTests([
            Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
        ])
        assertTrue(Workspace.get(byName: "a").focusWorkspace())
        assertTrue(monitors[1].setActiveWorkspace(Workspace.get(byName: "b")))

        let result = await parseCommand("focus-monitor left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["No monitors in direction left"])
        assertEquals(focus.workspace.name, "a")

        await parseCommand("focus-monitor --wrap-around left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "b")
    }

    func testFocusMonitorInDirection_verticalMonitors() async {
        let monitors = setUpMonitorsForTests([
            Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            Rect(topLeftX: 0, topLeftY: 1080, width: 1920, height: 1080),
        ])
        assertTrue(Workspace.get(byName: "a").focusWorkspace())
        assertTrue(monitors[1].setActiveWorkspace(Workspace.get(byName: "b")))

        let result = await parseCommand("focus-monitor right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["No monitors in direction right"])
        assertEquals(focus.workspace.name, "a")

        await parseCommand("focus-monitor down").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "b")
    }

    func testFocusMonitorNextPrev() async {
        let monitors = setUpMonitorsForTests([
            Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            Rect(topLeftX: -1920, topLeftY: 0, width: 1920, height: 1080),
        ])
        assertTrue(Workspace.get(byName: "a").focusWorkspace())
        assertTrue(monitors[1].setActiveWorkspace(Workspace.get(byName: "b")))
        assertTrue(monitors[2].setActiveWorkspace(Workspace.get(byName: "c")))

        // Monitors are ordered from left to right: c, a, b
        await parseCommand("focus-monitor next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "b")

        let result = await parseCommand("focus-monitor next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Can't find target monitor"])
        assertEquals(focus.workspace.name, "b")

        await parseCommand("focus-monitor --wrap-around next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "c")

        await parseCommand("focus-monitor --wrap-around prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "b")
    }

    func testFocusMonitorPatterns() async {
        let monitors = setUpMonitorsForTests([
            Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
        ])
        assertTrue(Workspace.get(byName: "a").focusWorkspace())
        assertTrue(monitors[1].setActiveWorkspace(Workspace.get(byName: "b")))

        await parseCommand("focus-monitor secondary").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "b")

        await parseCommand("focus-monitor main").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "a")

        await parseCommand("focus-monitor 'Test Monitor 2'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "b")

        await parseCommand("focus-monitor 1").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "a")
    }
}

@MainActor
private func parseFocusMonitorTarget(_ raw: String) -> MonitorTarget? {
    guard case .cmd(.cmd(let cmd)) = parseCommand(raw),
          let args = cmd.args as? FocusMonitorCmdArgs
    else { return nil }
    return args.target.val
}
