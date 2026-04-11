@testable import AppBundle
import Common
import XCTest

final class SubscribeCmdArgsTest: XCTestCase {
    func testParseValidEvents() {
        let result = parseSubscribeCmdArgs(["focus-changed", "mode-changed"].slice)
        switch result {
            case .cmd(let args):
                assertEquals(args.events, Set([.focusChanged, .modeChanged]))
            case .help, .failure:
                XCTFail("Expected success")
        }
    }

    func testParseAllFlag() {
        let result = parseSubscribeCmdArgs(["--all"].slice)
        switch result {
            case .cmd(let args):
                assertEquals(args.events, Set(ServerEventType.allCases))
            case .help, .failure:
                XCTFail("Expected success")
        }
    }

    func testParseUnknownEvent() {
        let result = parseSubscribeCmdArgs(["unknown-event"].slice)
        switch result {
            case .cmd, .help:
                XCTFail("Expected failure")
            case .failure(let err):
                let expectedMsg = """
                    ERROR: Can't parse 'unknown-event'.
                           Possible values: (focus-changed|focused-monitor-changed|focused-workspace-changed|mode-changed|window-detected|binding-triggered)
                    """
                assertEquals(err, .init(expectedMsg, 2))
        }
    }

    func testParseDuplicateEvent() {
        let result = parseSubscribeCmdArgs(["focus-changed", "focus-changed"].slice)
        switch result {
            case .cmd, .help:
                XCTFail("Expected failure")
            case .failure(let err):
                assertEquals(err, .init("ERROR: Duplicate event 'focus-changed'", 2))
        }
    }

    func testParseNoEvents() {
        let result = parseSubscribeCmdArgs([String]().slice)
        switch result {
            case .cmd, .help:
                XCTFail("Expected failure")
            case .failure(let err):
                assertEquals(err, .init("Either --all or at least one <event> must be specified", 2))
        }
    }

    func testParseAllWithEventsConflict() {
        let result = parseSubscribeCmdArgs(["--all", "focus-changed"].slice)
        switch result {
            case .cmd, .help:
                XCTFail("Expected failure")
            case .failure(let err):
                assertEquals(err, .init("--all conflicts with specifying individual events", 2))
        }
    }
}
