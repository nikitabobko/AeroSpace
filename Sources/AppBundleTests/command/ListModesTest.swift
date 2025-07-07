@testable import AppBundle
import Common
import XCTest

final class ListModesTest: XCTestCase {
    func testParseListModesCommand() {
        testParseCommandSucc("list-modes", ListModesCmdArgs(rawArgs: []))
        testParseCommandSucc("list-modes --current", ListModesCmdArgs(rawArgs: []).copy(\.current, true))
        testParseCommandSucc("list-modes --json", ListModesCmdArgs(rawArgs: []).copy(\.json, true))
        testParseCommandSucc("list-modes --count", ListModesCmdArgs(rawArgs: []).copy(\.outputOnlyCount, true))
        testParseCommandSucc("list-modes --current --json", ListModesCmdArgs(rawArgs: []).copy(\.current, true).copy(\.json, true))
    }

    func testParseListModesCommandConflicts() {
        assertEquals(parseCommand("list-modes --json --count").errorOrNil, "ERROR: Conflicting options: --count, --json")
        assertEquals(parseCommand("list-modes --current --count").errorOrNil, "ERROR: Conflicting options: --count, --current")
    }

    @MainActor
    func testListModesOutput() async throws {
        config.modes = [
            "main": Mode(name: nil, bindings: [:]),
            "service": Mode(name: nil, bindings: [:]),
            "resize": Mode(name: nil, bindings: [:]),
        ]

        let defaultResult = try await ListModesCommand(args: ListModesCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        assertEquals(defaultResult.exitCode, 0)
        assertEquals(defaultResult.stdout, ["main", "resize", "service"])
        assertEquals(defaultResult.stderr, [])

        let currentResult = try await ListModesCommand(args: ListModesCmdArgs(rawArgs: []).copy(\.current, true)).run(.defaultEnv, .emptyStdin)
        assertEquals(currentResult.exitCode, 0)
        assertEquals(currentResult.stdout, ["main"])
        assertEquals(currentResult.stderr, [])

        let countResult = try await ListModesCommand(args: ListModesCmdArgs(rawArgs: []).copy(\.outputOnlyCount, true)).run(.defaultEnv, .emptyStdin)
        assertEquals(countResult.exitCode, 0)
        assertEquals(countResult.stdout, ["3"])
        assertEquals(countResult.stderr, [])

        let jsonResult = try await ListModesCommand(args: ListModesCmdArgs(rawArgs: []).copy(\.json, true)).run(.defaultEnv, .emptyStdin)
        let expectedJson = JSONEncoder.aeroSpaceDefault.encodeToString([
            ["mode-id": "main"],
            ["mode-id": "resize"],
            ["mode-id": "service"],
        ])
        assertEquals(jsonResult.exitCode, 0)
        assertEquals(jsonResult.stdout, [expectedJson])
        assertEquals(jsonResult.stderr, [])

        let currentJsonResult = try await ListModesCommand(args: ListModesCmdArgs(rawArgs: []).copy(\.current, true).copy(\.json, true)).run(.defaultEnv, .emptyStdin)
        let expectedCurrentJson = JSONEncoder.aeroSpaceDefault.encodeToString([
            ["mode-id": "main"],
        ])
        assertEquals(currentJsonResult.exitCode, 0)
        assertEquals(currentJsonResult.stdout, [expectedCurrentJson])
        assertEquals(currentJsonResult.stderr, [])
    }
}
