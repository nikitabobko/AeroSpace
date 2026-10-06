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

        for window in workspace.rootTilingContainer.children {
            assertEquals(window.getWeight(workspace.rootTilingContainer.orientation), 6 / 3)
        }
    }

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

    func testBalanceSizesSkipsTombstones() async {
        var invisibleWindow: Window!
        var invisibleContainer: TilingContainer!
        var invisibleNestedWindow: Window!
        var nestedWindows: [Window] = []
        let workspace = Workspace.get(byName: name).apply { wsp in
            wsp.rootTilingContainer.apply {
                let orientation = wsp.rootTilingContainer.orientation
                TestWindow.new(id: 1, parent: $0).setWeight(orientation, 1)
                invisibleWindow = TestWindow.new(id: 2, parent: $0).apply {
                    $0.setWeight(orientation, 10)
                    $0.lifeStatus = .invisible
                }
                TestWindow.new(id: 3, parent: $0).setWeight(orientation, 3)
                invisibleContainer = TilingContainer.newVTiles(parent: $0, adaptiveWeight: 20).apply {
                    invisibleNestedWindow = TestWindow.new(id: 4, parent: $0).apply {
                        $0.setWeight(.v, 40)
                        $0.lifeStatus = .dead
                    }
                    $0.lifeStatus = .deadOrInvisible
                }
                TilingContainer.newVTiles(parent: $0, adaptiveWeight: 5).apply {
                    nestedWindows.append(TestWindow.new(id: 5, parent: $0).apply { $0.setWeight(.v, 1) })
                    nestedWindows.append(TestWindow.new(id: 6, parent: $0).apply { $0.setWeight(.v, 5) })
                }
            }
        }
        let orientation = workspace.rootTilingContainer.orientation

        await parseCommand("balance-sizes").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(name), .emptyStdin)

        // (1 + 3 + 5) / 3
        for child in workspace.rootTilingContainer.inhabitedChildren {
            assertEquals(child.getWeight(orientation), 3)
        }
        for window in nestedWindows {
            assertEquals(window.getWeight(.v), 3)
        }
        assertEquals(invisibleWindow.getWeight(orientation), 10)
        assertEquals(invisibleContainer.getWeight(orientation), 20)
        assertEquals(invisibleNestedWindow.getWeight(.v), 40)
    }
}
