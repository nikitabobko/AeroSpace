@testable import AppBundle
import Common
import XCTest

@MainActor
final class BalanceSizesCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testBalanceSizesCommand() async {
        let workspace = Workspace.get(byName: name).apply { wsp in
            wsp.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0).setWeight(wsp.rootTilingContainer.orientation, 1)
                TestWindow.new(id: 2, parent: $0).setWeight(wsp.rootTilingContainer.orientation, 2)
                TestWindow.new(id: 3, parent: $0).setWeight(wsp.rootTilingContainer.orientation, 3)
            }
        }

        await parseCommand("balance-sizes").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(name), .emptyStdin)

        // The total (1 + 2 + 3) is preserved and split equally
        for window in workspace.rootTilingContainer.children {
            assertEquals(window.getWeight(workspace.rootTilingContainer.orientation), 2)
        }
    }

    func testBalanceSizes_nestedContainerPreservesItsOwnTotal() async {
        var container: TilingContainer!
        var window1: Window!
        var window2: Window!
        var window3: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            window1 = TestWindow.new(id: 1, parent: $0, adaptiveWeight: 4)
            container = TilingContainer.newVTiles(parent: $0, adaptiveWeight: 8).apply {
                window2 = TestWindow.new(id: 2, parent: $0, adaptiveWeight: 1)
                window3 = TestWindow.new(id: 3, parent: $0, adaptiveWeight: 5)
            }
        }

        await parseCommand("balance-sizes").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(name), .emptyStdin)

        assertEquals(window1.hWeight, 6) // (4 + 8) / 2
        assertEquals(container.hWeight, 6)
        assertEquals(window2.vWeight, 3) // (1 + 5) / 2
        assertEquals(window3.vWeight, 3)
    }

    // https://github.com/nikitabobko/AeroSpace/issues/1837
    func testBalanceSizesThenResize_behavesLikeResizeAlone() async {
        var window1: Window!
        var window2: Window!
        var window3: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            window1 = TestWindow.new(id: 1, parent: $0, adaptiveWeight: 2)
            window2 = TestWindow.new(id: 2, parent: $0, adaptiveWeight: 4)
            window3 = TestWindow.new(id: 3, parent: $0, adaptiveWeight: 6)
        }
        _ = window1.focusWindow()

        // Both commands run within a single session, so no layout pass normalizes the weights in between
        await parseCommand("balance-sizes").cmdOrDie.run(.defaultEnv, .emptyStdin)
        await parseCommand("resize width 6").cmdOrDie.run(.defaultEnv, .emptyStdin)

        // balance-sizes makes it 4, 4, 4. Then diff = 6 - 4 = 2, childDiff = 1
        assertEquals(window1.hWeight, 6)
        assertEquals(window2.hWeight, 3)
        assertEquals(window3.hWeight, 3)
        // The total is unchanged, so the following layout pass doesn't scale the windows up
        assertEquals(window1.hWeight + window2.hWeight + window3.hWeight, 12)
    }
}
