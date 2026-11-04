@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct SubscribeCmdArgsTest {
    @Test func testParseValidEvents() {
        let result = parseSubscribeCmdArgs(["focus-changed", "mode-changed"].slice)
        switch result {
            case .cmd(let args):
                assertEquals(args.events, Set([.focusChanged, .modeChanged]))
            case .help, .failure:
                Issue.record(Comment(rawValue: "Expected success"))
        }
    }

    @Test func testParseAllFlag() {
        let result = parseSubscribeCmdArgs(["--all"].slice)
        switch result {
            case .cmd(let args):
                assertEquals(args.events, Set(ServerEventType.allCases))
            case .help, .failure:
                Issue.record(Comment(rawValue: "Expected success"))
        }
    }

    @Test func testParseUnknownEvent() {
        let result = parseSubscribeCmdArgs(["unknown-event"].slice)
        switch result {
            case .cmd, .help:
                Issue.record(Comment(rawValue: "Expected failure"))
            case .failure(let err):
                let expectedMsg = """
                    ERROR: Can't parse 'unknown-event'.
                           Possible values: (focus-changed|focused-monitor-changed|focused-workspace-changed|mode-changed|window-detected|binding-triggered)
                    """
                assertEquals(err, .init(expectedMsg, 2))
        }
    }

    @Test func testParseDuplicateEvent() {
        let result = parseSubscribeCmdArgs(["focus-changed", "focus-changed"].slice)
        switch result {
            case .cmd, .help:
                Issue.record(Comment(rawValue: "Expected failure"))
            case .failure(let err):
                assertEquals(err, .init("ERROR: Duplicate event 'focus-changed'", 2))
        }
    }

    @Test func testParseNoEvents() {
        let result = parseSubscribeCmdArgs([String]().slice)
        switch result {
            case .cmd, .help:
                Issue.record(Comment(rawValue: "Expected failure"))
            case .failure(let err):
                assertEquals(err, .init("Either --all or at least one <event> must be specified", 2))
        }
    }

    @Test func testParseAllWithEventsConflict() {
        let result = parseSubscribeCmdArgs(["--all", "focus-changed"].slice)
        switch result {
            case .cmd, .help:
                Issue.record(Comment(rawValue: "Expected failure"))
            case .failure(let err):
                assertEquals(err, .init("--all conflicts with specifying individual events", 2))
        }
    }
}
