@testable import AppBundle
import Common
import XCTest

@MainActor
final class ResizeCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParseCommand() {
        testParseSingleCommandSucc("resize smart +10", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(10)))
        testParseSingleCommandSucc("resize smart -10", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .subtract(10)))
        testParseSingleCommandSucc("resize smart 10", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .set(10)))

        testParseSingleCommandSucc("resize smart-opposite +10", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .add(10)))
        testParseSingleCommandSucc("resize smart-opposite -10", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .subtract(10)))
        testParseSingleCommandSucc("resize smart-opposite 10", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .set(10)))

        testParseSingleCommandSucc("resize height 10", ResizeCmdArgs(rawArgs: [], dimension: .height, units: .set(10)))
        testParseSingleCommandSucc("resize width 10", ResizeCmdArgs(rawArgs: [], dimension: .width, units: .set(10)))

        testParseCommandFail("resize s 10", msg: """
            ERROR: Can't parse 's'.
                   Possible values: (width|height|smart|smart-opposite)
            """, exitCode: 2)
        testParseCommandFail("resize smart foo", msg: "ERROR: <number> argument must be a number", exitCode: 2)
    }

    func testWidthAdd_growsTargetShrinksSiblings() async {
        var window1: Window!
        var window2: Window!
        var window3: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            window1 = TestWindow.new(id: 1, parent: $0, adaptiveWeight: 4)
            window2 = TestWindow.new(id: 2, parent: $0, adaptiveWeight: 4)
            window3 = TestWindow.new(id: 3, parent: $0, adaptiveWeight: 4)
        }
        _ = window1.focusWindow()

        await parseCommand("resize width +2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        // diff = +2, childDiff = 2 / (3 - 1) = 1
        assertEquals(window1.hWeight, 6)
        assertEquals(window2.hWeight, 3)
        assertEquals(window3.hWeight, 3)
    }

    func testWidthSubtract_shrinksTargetGrowsSiblings() async {
        var window1: Window!
        var window2: Window!
        var window3: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            window1 = TestWindow.new(id: 1, parent: $0, adaptiveWeight: 4)
            window2 = TestWindow.new(id: 2, parent: $0, adaptiveWeight: 4)
            window3 = TestWindow.new(id: 3, parent: $0, adaptiveWeight: 4)
        }
        _ = window1.focusWindow()

        await parseCommand("resize width -2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        // diff = -2, childDiff = -1
        assertEquals(window1.hWeight, 2)
        assertEquals(window2.hWeight, 5)
        assertEquals(window3.hWeight, 5)
    }

    func testWidthSet_diffIsAbsoluteMinusCurrent() async {
        var window1: Window!
        var window2: Window!
        var window3: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            window1 = TestWindow.new(id: 1, parent: $0, adaptiveWeight: 4)
            window2 = TestWindow.new(id: 2, parent: $0, adaptiveWeight: 4)
            window3 = TestWindow.new(id: 3, parent: $0, adaptiveWeight: 4)
        }
        _ = window1.focusWindow()

        await parseCommand("resize width 6").cmdOrDie.run(.defaultEnv, .emptyStdin)
        // diff = 6 - 4 = 2, childDiff = 1
        assertEquals(window1.hWeight, 6)
        assertEquals(window2.hWeight, 3)
        assertEquals(window3.hWeight, 3)
    }

    func testHeight_climbsToVerticalAncestor() async {
        // Root is horizontal; height must locate the nested vertical tile container.
        var window1: Window!
        var window2: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 0, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                window1 = TestWindow.new(id: 1, parent: $0, adaptiveWeight: 4)
                window2 = TestWindow.new(id: 2, parent: $0, adaptiveWeight: 4)
            }
        }
        _ = window1.focusWindow()

        await parseCommand("resize height +2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        // diff = +2, childDiff = 2 / (2 - 1) = 2
        assertEquals(window1.vWeight, 6)
        assertEquals(window2.vWeight, 2)
    }

    func testSmart_usesImmediateParentOrientation() async {
        // .smart resizes along the immediate tile container's axis, even when an ancestor
        // would also qualify.
        var window1: Window!
        var window2: Window!
        var sibling: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 4).apply {
                window1 = TestWindow.new(id: 1, parent: $0, adaptiveWeight: 4)
                window2 = TestWindow.new(id: 2, parent: $0, adaptiveWeight: 4)
            }
            sibling = TestWindow.new(id: 3, parent: $0, adaptiveWeight: 4)
        }
        _ = window1.focusWindow()

        await parseCommand("resize smart +2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        // immediate parent is vertical; resize is along .v
        assertEquals(window1.vWeight, 6)
        assertEquals(window2.vWeight, 2)
        // The horizontal sibling at the root is untouched.
        assertEquals(sibling.hWeight, 4)
    }

    func testSmartOpposite_resizesAncestorContainer() async {
        // .smart-opposite resolves to the opposite axis (.h here) and climbs to the
        // ancestor tile container with that orientation. That ancestor's child — the
        // intermediate vertical container — is the node that gets resized.
        var verticalContainer: TilingContainer!
        var sibling: Window!
        var inner: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            verticalContainer = TilingContainer.newVTiles(parent: $0, adaptiveWeight: 4).apply {
                inner = TestWindow.new(id: 1, parent: $0)
                TestWindow.new(id: 2, parent: $0)
            }
            sibling = TestWindow.new(id: 3, parent: $0, adaptiveWeight: 4)
        }
        _ = inner.focusWindow()

        await parseCommand("resize smart-opposite +2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        // diff = +2 along .h; root has 2 children, childDiff = 2
        assertEquals(verticalContainer.hWeight, 6)
        assertEquals(sibling.hWeight, 2)
    }

    func testHeight_noVerticalAncestor_returnsFail() async {
        // Root is horizontal; with no vertical container present, height has nothing to resize.
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        let result = await parseCommand("resize height +2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
    }

    func testSingleChildParent_failsCleanly() async {
        // The root has only one tiling child; dividing the diff across 0 siblings must fail.
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0, adaptiveWeight: 4).focusWindow(), true)
        }

        let result = await parseCommand("resize width +2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
    }
}
