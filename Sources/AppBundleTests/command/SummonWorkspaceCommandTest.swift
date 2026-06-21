@testable import AppBundle
import Common
import XCTest

@MainActor
final class SummonWorkspaceCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        assertEquals(parseCommand("summon-workspace").errorOrNil, "ERROR: Argument '<workspace>' is mandatory")
        testParseSingleCommandSucc("summon-workspace foo", SummonWorkspaceCmdArgs(rawArgs: []).copy(\.target, .initialized(.parse("foo").getOrDie())))
    }

    func testParseDashDash() {
        testParseSingleCommandSucc(
            "summon-workspace -- foo",
            SummonWorkspaceCmdArgs(rawArgs: []).copy(\.target, .initialized(.parse("foo").getOrDie())),
        )
        testParseSingleCommandSucc(
            "summon-workspace --fail-if-noop -- foo",
            SummonWorkspaceCmdArgs(rawArgs: []).copy(\.target, .initialized(.parse("foo").getOrDie())).copy(\.failIfNoop, true),
        )
        assertEquals(parseCommand("summon-workspace --").errorOrNil, "ERROR: Argument '<workspace>' is mandatory")
        assertEquals(parseCommand("summon-workspace -- --fail-if-noop").errorOrNil, "ERROR: Workspace names starting with dash are disallowed")
    }
}
