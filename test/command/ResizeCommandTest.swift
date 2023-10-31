import XCTest
@testable import AeroSpace_Debug

final class ResizeCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParseCommand() {
        testParseCommandSucc("resize smart +10", .resizeCommand(dimension: .smart, mode: .add, unit: 10))
        testParseCommandSucc("resize smart -10", .resizeCommand(dimension: .smart, mode: .subtract, unit: 10))
        testParseCommandSucc("resize smart 10", .resizeCommand(dimension: .smart, mode: .set, unit: 10))

        testParseCommandSucc("resize height 10", .resizeCommand(dimension: .height, mode: .set, unit: 10))
        testParseCommandSucc("resize width 10", .resizeCommand(dimension: .width, mode: .set, unit: 10))

        testParseCommandFail("resize s 10", msg: "Can't parse 'resize' first arg")
        testParseCommandFail("resize smart foo", msg: "'resize' command: Second arg must be a number")
    }
}

private func testParseCommandSucc(_ command: String, _ expected: CommandDescription) {
    let parsed = parseSingleCommand(command)
    switch parsed {
    case .success(let command):
        XCTAssertEqual(command.describe, expected)
    case .failure(let msg):
        XCTFail(msg)
    }
}

private func testParseCommandFail(_ command: String, msg expected: String) {
    let parsed = parseSingleCommand(command)
    switch parsed {
    case .success(let command):
        XCTFail("\(command) isn't supposed to be parcelable")
    case .failure(let msg):
        XCTAssertEqual(msg, expected)
    }
}
