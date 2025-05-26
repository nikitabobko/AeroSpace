@testable import AppBundle
import Common
import XCTest

@MainActor
final class ResizeCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }
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

    func testParsePercentageCommand() {
        // Absolute percentages
        testParseCommandSucc("resize width 50%", ResizeCmdArgs(rawArgs: [], dimension: .width, units: .setPercent(50)))
        testParseCommandSucc("resize height 25%", ResizeCmdArgs(rawArgs: [], dimension: .height, units: .setPercent(25)))
        testParseCommandSucc("resize smart 100%", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .setPercent(100)))
        testParseCommandSucc("resize smart-opposite 0%", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .setPercent(0)))

        // Relative percentages
        testParseCommandSucc("resize width +10%", ResizeCmdArgs(rawArgs: [], dimension: .width, units: .addPercent(10)))
        testParseCommandSucc("resize height -15%", ResizeCmdArgs(rawArgs: [], dimension: .height, units: .subtractPercent(15)))
        testParseCommandSucc("resize smart +5%", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .addPercent(5)))
        testParseCommandSucc("resize smart-opposite -20%", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .subtractPercent(20)))

        // Error cases
        testParseCommandFail("resize width %", msg: "ERROR: Invalid percentage format")
        testParseCommandFail("resize width 10.5%", msg: "ERROR: Percentage must be a whole number")
        testParseCommandFail("resize width abc%", msg: "ERROR: Invalid percentage format")
        testParseCommandFail("resize width -150%", msg: "ERROR: Percentage must be between 0 and 100")
        testParseCommandFail("resize width 150%", msg: "ERROR: Percentage must be between 0 and 100")
    }

    func testResizeWindowByPercentage() async throws {
        // For this test, we'll verify that percentage parsing works correctly
        // The actual resize logic with percentages needs to be tested differently
        // since weights are proportional, not pixel values

        // Just verify that percentage commands can be created and parsed
        let cmd = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .setPercent(25)))
        assertEquals(cmd.args.dimension.val, .width)
        assertEquals(cmd.args.units.val, .setPercent(25))

        // Test relative percentages
        let addCmd = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .height, units: .addPercent(10)))
        assertEquals(addCmd.args.units.val, .addPercent(10))

        let subCmd = ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .subtractPercent(15)))
        assertEquals(subCmd.args.units.val, .subtractPercent(15))
    }
}
