@testable import AppBundle
import Common
import XCTest

@MainActor
final class CycleSizeCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParseCommand() {
        testParseSingleCommandSucc("cycle-size 33% 50% 66%", CycleSizeCmdArgs(rawArgs: [], sizes: [33, 50, 66]))
        testParseSingleCommandSucc("cycle-size 1% 99%", CycleSizeCmdArgs(rawArgs: [], sizes: [1, 99]))
        testParseSingleCommandSucc(
            "cycle-size --axis width 50%",
            CycleSizeCmdArgs(rawArgs: [], sizes: [50], axis: .width),
        )
        testParseSingleCommandSucc(
            "cycle-size 50% --axis smart-opposite",
            CycleSizeCmdArgs(rawArgs: [], sizes: [50], axis: .smartOpposite),
        )

        // --axis is optional, and it defaults to smart
        assertEquals(CycleSizeCmdArgs(rawArgs: [], sizes: [50]).axis, .smart)
        assertEquals(CycleSizeCmdArgs(rawArgs: [], sizes: [50], axis: .height).axis, .height)

        assertEquals(parseCommand("cycle-size").errorOrNil, "ERROR: Argument '(<size>%)...' is mandatory")
        testParseCommandFail("cycle-size 50", msg: """
            ERROR: Can't parse '50'
                   <size> must be an integer in range 1-99 followed by '%'. For example: 50%
            """, exitCode: 2)
        testParseCommandFail("cycle-size 0%", msg: """
            ERROR: Can't parse '0%'
                   <size> must be an integer in range 1-99 followed by '%'. For example: 50%
            """, exitCode: 2)
        testParseCommandFail("cycle-size 100%", msg: """
            ERROR: Can't parse '100%'
                   <size> must be an integer in range 1-99 followed by '%'. For example: 50%
            """, exitCode: 2)
        testParseCommandFail("cycle-size --axis foo 50%", msg: """
            ERROR: Can't parse 'foo'.
                   Possible values: (width|height|smart|smart-opposite)
            """, exitCode: 2)
    }

    func testCycle_advancesToTheNextSize() async {
        var window1: Window!
        var window2: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            window1 = TestWindow.new(id: 1, parent: $0, adaptiveWeight: 50)
            window2 = TestWindow.new(id: 2, parent: $0, adaptiveWeight: 50)
        }
        _ = window1.focusWindow()

        await parseCommand("cycle-size 25% 50% 75%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        // The current size is 50%. The next one is 75% of 100 = 75. diff = +25, childDiff = 25
        assertEquals(window1.hWeight, 75)
        assertEquals(window2.hWeight, 25)
    }

    func testCycle_wrapsAroundToTheFirstSize() async {
        var window1: Window!
        var window2: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            window1 = TestWindow.new(id: 1, parent: $0, adaptiveWeight: 150)
            window2 = TestWindow.new(id: 2, parent: $0, adaptiveWeight: 150)
        }
        _ = window1.focusWindow()

        await parseCommand("cycle-size 25% 50%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        // The current size is the last one (50%), so the cycle wraps around to 25% of 300 = 75
        assertEquals(window1.hWeight, 75)
        assertEquals(window2.hWeight, 225)
    }

    func testCycle_roundsTheCurrentSizeToWholePercent() async {
        var window1: Window!
        var window2: Window!
        var window3: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            window1 = TestWindow.new(id: 1, parent: $0, adaptiveWeight: 100)
            window2 = TestWindow.new(id: 2, parent: $0, adaptiveWeight: 100)
            window3 = TestWindow.new(id: 3, parent: $0, adaptiveWeight: 100)
        }
        _ = window1.focusWindow()

        await parseCommand("cycle-size 33% 60%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        // 100/300 is 33.33% which rounds to the requested 33%, so the next size is 60% of 300 = 180
        // diff = +80, childDiff = 80 / (3 - 1) = 40
        assertEquals(window1.hWeight, 180)
        assertEquals(window2.hWeight, 60)
        assertEquals(window3.hWeight, 60)
    }

    func testUnknownCurrentSize_jumpsToTheFirstSize() async {
        var window1: Window!
        var window2: Window!
        var window3: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            window1 = TestWindow.new(id: 1, parent: $0, adaptiveWeight: 100)
            window2 = TestWindow.new(id: 2, parent: $0, adaptiveWeight: 100)
            window3 = TestWindow.new(id: 3, parent: $0, adaptiveWeight: 100)
        }
        _ = window1.focusWindow()

        await parseCommand("cycle-size 50% 60%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        // 33% isn't requested, so the first size is applied. 50% of 300 = 150. diff = +50, childDiff = 25
        assertEquals(window1.hWeight, 150)
        assertEquals(window2.hWeight, 75)
        assertEquals(window3.hWeight, 75)
    }

    func testAxisHeight_climbsToVerticalAncestor() async {
        // Root is horizontal; height must locate the nested vertical tile container.
        var window1: Window!
        var window2: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 0, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                window1 = TestWindow.new(id: 1, parent: $0, adaptiveWeight: 100)
                window2 = TestWindow.new(id: 2, parent: $0, adaptiveWeight: 100)
            }
        }
        _ = window1.focusWindow()

        await parseCommand("cycle-size --axis height 25% 75%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        // 50% isn't requested, so the first size is applied. 25% of 200 = 50. diff = -50, childDiff = -50
        assertEquals(window1.vWeight, 50)
        assertEquals(window2.vWeight, 150)
    }

    func testAxisSmartOpposite_cyclesTheAncestorContainer() async {
        // .smart-opposite resolves to the opposite axis (.h here) and climbs to the
        // ancestor tile container with that orientation.
        var verticalContainer: TilingContainer!
        var sibling: Window!
        var inner: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            verticalContainer = TilingContainer.newVTiles(parent: $0, adaptiveWeight: 100).apply {
                inner = TestWindow.new(id: 1, parent: $0)
                TestWindow.new(id: 2, parent: $0)
            }
            sibling = TestWindow.new(id: 3, parent: $0, adaptiveWeight: 100)
        }
        _ = inner.focusWindow()

        await parseCommand("cycle-size --axis smart-opposite 25% 75%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        // 50% isn't requested, so the first size is applied. 25% of 200 = 50. diff = -50, childDiff = -50
        assertEquals(verticalContainer.hWeight, 50)
        assertEquals(sibling.hWeight, 150)
    }

    func testSingleChildParent_failsCleanly() async {
        // The root has only one tiling child; there are no siblings to compensate the change on.
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0, adaptiveWeight: 100).focusWindow(), true)
        }

        let result = await parseCommand("cycle-size 50%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
    }

    func testAxisHeight_noVerticalAncestor_returnsFail() async {
        // Root is horizontal; with no vertical container present, height has nothing to resize.
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        let result = await parseCommand("cycle-size --axis height 50%").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
    }
}
