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
                XCTAssert(err.contains("Unknown event"))
        }
    }

    func testParseDuplicateEvent() {
        let result = parseSubscribeCmdArgs(["focus-changed", "focus-changed"].slice)
        switch result {
            case .cmd, .help:
                XCTFail("Expected failure")
            case .failure(let err):
                XCTAssert(err.contains("Duplicate event"))
        }
    }

    func testParseNoEvents() {
        let result = parseSubscribeCmdArgs([String]().slice)
        switch result {
            case .cmd, .help:
                XCTFail("Expected failure")
            case .failure(let err):
                XCTAssert(err.contains("Either --all or at least one"))
        }
    }

    func testParseAllWithEventsConflict() {
        let result = parseSubscribeCmdArgs(["--all", "focus-changed"].slice)
        switch result {
            case .cmd, .help:
                XCTFail("Expected failure")
            case .failure(let err):
                XCTAssert(err.contains("--all conflicts"))
        }
    }
}
