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

    @Test func testParseWhenVisible() {
        let foo = SummonWorkspaceCmdArgs(rawArgs: []).with(\.target, .initialized(.parse("foo").getOrDie()))
        assertEquals(foo.whenVisible, .move)
        testParseSingleCommandSucc("summon-workspace --when-visible move foo", foo.with(\.rawWhenVisibleAction, .move))
        testParseSingleCommandSucc("summon-workspace --when-visible focus foo", foo.with(\.rawWhenVisibleAction, .focus))
        testParseSingleCommandSucc("summon-workspace --when-visible swap foo", foo.with(\.rawWhenVisibleAction, .swap))
        assertEquals(
            parseCommand("summon-workspace --when-visible bar foo").errorOrNil,
            "ERROR: Can't parse 'bar'.\n       Possible values: (move|focus|swap)",
        )
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
