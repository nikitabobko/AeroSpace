@testable import AppBundle
import Common
import XCTest

final class ListModesTest: XCTestCase {
    func testParseListModesCommand() {
        testParseSingleCommandSucc("list-modes", ListModesCmdArgs(rawArgs: []))
        testParseSingleCommandSucc("list-modes --current", ListModesCmdArgs(rawArgs: []).copy(\.current, true))
        testParseSingleCommandSucc("list-modes --json", ListModesCmdArgs(rawArgs: []).copy(\.json, true))
        testParseSingleCommandSucc("list-modes --count", ListModesCmdArgs(rawArgs: []).copy(\.outputOnlyCount, true))
        testParseSingleCommandSucc("list-modes --current --json", ListModesCmdArgs(rawArgs: []).copy(\.current, true).copy(\.json, true))
    }

    func testParseListModesCommandConflicts() {
        assertEquals(parseCommand("list-modes --json --count").errorOrNil, "ERROR: Conflicting options: --count, --json")
        assertEquals(parseCommand("list-modes --current --count").errorOrNil, "ERROR: Conflicting options: --count, --current")
    }

    @MainActor
    func testListModesOutput() async {
        config.modes = [
            "main": Mode(bindings: [:]),
            "service": Mode(bindings: [:]),
            "resize": Mode(bindings: [:]),
        ]

        let defaultResult = await parseCommand("list-modes").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(defaultResult.exitCode.rawValue, 0)
        assertEquals(defaultResult.stdout, ["main", "resize", "service"])
        assertEquals(defaultResult.stderr, [])

        let currentResult = await parseCommand("list-modes --current").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(currentResult.exitCode.rawValue, 0)
        assertEquals(currentResult.stdout, ["main"])
        assertEquals(currentResult.stderr, [])

        let countResult = await parseCommand("list-modes --count").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(countResult.exitCode.rawValue, 0)
        assertEquals(countResult.stdout, ["3"])
        assertEquals(countResult.stderr, [])

        let jsonResult = await parseCommand("list-modes --json").cmdOrDie.run(.defaultEnv, .emptyStdin)
        let expectedJson = JSONEncoder.aeroSpaceDefault.encodeToString([
            ["mode-id": "main"],
            ["mode-id": "resize"],
            ["mode-id": "service"],
        ])
        assertEquals(jsonResult.exitCode.rawValue, 0)
        assertEquals(jsonResult.stdout, [expectedJson])
        assertEquals(jsonResult.stderr, [])

        let currentJsonResult = await parseCommand("list-modes --current --json").cmdOrDie.run(.defaultEnv, .emptyStdin)
        let expectedCurrentJson = JSONEncoder.aeroSpaceDefault.encodeToString([
            ["mode-id": "main"],
        ])
        assertEquals(currentJsonResult.exitCode.rawValue, 0)
        assertEquals(currentJsonResult.stdout, [expectedCurrentJson])
        assertEquals(currentJsonResult.stderr, [])
    }
}
