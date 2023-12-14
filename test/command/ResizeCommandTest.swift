import XCTest
@testable import AeroSpace_Debug

final class ResizeCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testParseCommand() {
        testParseCommandSucc("resize smart +10", .resizeCommand(args: ResizeCmdArgs(dimension: .smart, units: .add(10))))
        testParseCommandSucc("resize smart -10", .resizeCommand(args: ResizeCmdArgs(dimension: .smart, units: .subtract(10))))
        testParseCommandSucc("resize smart 10", .resizeCommand(args: ResizeCmdArgs(dimension: .smart, units: .set(10))))

        testParseCommandSucc("resize height 10", .resizeCommand(args: ResizeCmdArgs(dimension: .height, units: .set(10))))
        testParseCommandSucc("resize width 10", .resizeCommand(args: ResizeCmdArgs(dimension: .width, units: .set(10))))

        testParseCommandFail("resize s 10", msg: """
                                                 ERROR: Can't parse 's'.
                                                        Possible values: (width|height|smart)
                                                 """)
        testParseCommandFail("resize smart foo", msg: "ERROR: <number> argument must be a number")
    }
}
