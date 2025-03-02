@testable import AppBundle
import Common
import XCTest

final class ResizeCommandTest: XCTestCase {
    func testParseCommand() {
        testParseCommandSucc("resize smart +10", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(10)))
        testParseCommandSucc("resize smart -10", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .subtract(10)))
        testParseCommandSucc("resize smart 10", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .set(10)))

        testParseCommandSucc("resize smart-opposite +10", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .add(10)))
        testParseCommandSucc("resize smart-opposite -10", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .subtract(10)))
        testParseCommandSucc("resize smart-opposite 10", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .set(10)))

        testParseCommandSucc("resize height 10", ResizeCmdArgs(rawArgs: [], dimension: .height, units: .set(10)))
        testParseCommandSucc("resize width 10", ResizeCmdArgs(rawArgs: [], dimension: .width, units: .set(10)))

        testParseCommandFail("resize s 10", msg: """
            ERROR: Can't parse 's'.
                   Possible values: (width|height|smart|smart-opposite)
            """)
        testParseCommandFail("resize smart foo", msg: "ERROR: <number> argument must be a number")
    }
}
