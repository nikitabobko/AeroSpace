@testable import AppBundle
import Common
import XCTest

@MainActor
final class FocusMonitorBackAndForthCommandTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        _prevFocusedMonitorPoint = nil
    }

    func testParse() {
        testParseSingleCommandSucc("focus-monitor-back-and-forth", FocusMonitorBackAndForthCmdArgs(rawArgs: []))
        testParseCommandFail("focus-monitor-back-and-forth next", msg: "ERROR: Unknown argument 'next'", exitCode: 2)
        testParseCommandFail("focus-monitor-back-and-forth --wrap-around", msg: "ERROR: Unknown flag '--wrap-around'", exitCode: 2)
    }

    func testNoPrevMonitor_fails() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())
        // _prevFocusedMonitorPoint is nil from setUp — the focus hasn't left the focused monitor yet

        let result = await parseCommand("focus-monitor-back-and-forth").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["Can't find prev monitor"])
        assertEquals(focus.workspace.name, "a")
    }

    func testPrevMonitorIsDisconnected_fails() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())
        _prevFocusedMonitorPoint = .init(x: 1920, y: 0) // No monitor sits at this point anymore

        let result = await parseCommand("focus-monitor-back-and-forth").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Can't find prev monitor"])
        assertEquals(focus.workspace.name, "a")
    }

    func testPrevMonitor_focusesItsVisibleWorkspace() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())
        _prevFocusedMonitorPoint = mainMonitorInfo.rect.topLeftCorner

        let result = await parseCommand("focus-monitor-back-and-forth").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, [])
        assertEquals(focus.workspace.name, mainMonitorInfo.activeWorkspace.name)
    }

    func testFocusChangeWithinTheMonitor_doesNotRecordPrevMonitor() async {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())
        await checkOnFocusChangedCallbacks_nonCancellable()
        assertTrue(Workspace.get(byName: "b").focusWorkspace())
        await checkOnFocusChangedCallbacks_nonCancellable()

        assertEquals(_prevFocusedWorkspaceName, "a") // The callbacks did observe the focus change
        assertNil(_prevFocusedMonitorPoint) // But the monitor hasn't changed
    }
}
