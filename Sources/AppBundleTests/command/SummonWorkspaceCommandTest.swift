@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct SummonWorkspaceCommandTest {
    init() { setUpWorkspacesForTests() }

    @Test func testParse() {
        assertEquals(parseCommand("summon-workspace").errorOrNil, "ERROR: Argument '<workspace>' is mandatory")
        testParseSingleCommandSucc("summon-workspace foo", SummonWorkspaceCmdArgs(rawArgs: []).with(\.target, .initialized(.parse("foo").getOrDie())))
    }

    @Test func testParseDoubleDash() {
        testParseSingleCommandSucc(
            "summon-workspace -- foo",
            SummonWorkspaceCmdArgs(rawArgs: []).with(\.target, .initialized(.parse("foo").getOrDie())),
        )
        testParseSingleCommandSucc(
            "summon-workspace --fail-if-noop -- foo",
            SummonWorkspaceCmdArgs(rawArgs: []).with(\.target, .initialized(.parse("foo").getOrDie())).with(\.failIfNoop, true),
        )
        assertEquals(parseCommand("summon-workspace --").errorOrNil, "ERROR: Argument '<workspace>' is mandatory")
        assertEquals(parseCommand("summon-workspace -- --fail-if-noop").errorOrNil, "ERROR: Workspace names starting with dash are disallowed")
    }
}
