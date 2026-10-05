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
            assertEquals(window.getWeight(workspace.rootTilingContainer.orientation), 1)
        }
    }

    func testBalanceSizesResetsClosedWindowsCache() async throws {
        resetClosedWindowsCache()
        defer { resetClosedWindowsCache() }

        let workspace = Workspace.get(byName: name)
        let window1 = TestWindow.new(id: 1, parent: workspace.rootTilingContainer, adaptiveWeight: 100)
        let window2 = TestWindow.new(id: 2, parent: workspace.rootTilingContainer, adaptiveWeight: 300)
        let closedWindow = TestWindow.new(id: 3, parent: workspace.rootTilingContainer)
        _ = window1.focusWindow()

        cacheClosedWindowIfNeeded()
        closedWindow.unbindFromParent()

        let result = await parseCommand("balance-sizes").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(name), .emptyStdin)

        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(window1.hWeight, window2.hWeight)
        assertFalse(try await restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: closedWindow))
    }
}
