@testable import AppBundle
import Common
import Foundation
import XCTest

@MainActor
final class ClosedWindowsCacheTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        resetClosedWindowsCache()
    }

    override func tearDown() async throws { resetClosedWindowsCache() }

    func testRestoreKeepsMruOrder() async throws {
        let a = Workspace.get(byName: "a")
        let b = Workspace.get(byName: "b")
        let root = a.rootTilingContainer.apply {
            $0.layout = .accordion
            $0.changeOrientation(.v)
            TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 1, parent: $0)
                TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 2, parent: $0)
                    TestWindow.new(id: 3, parent: $0)
                }
            }
            TestWindow.new(id: 4, parent: $0)
            TestWindow.new(id: 5, parent: $0)
        }
        TestWindow.new(id: 6, parent: b.rootTilingContainer)
        assertTrue(Window.get(byId: 5)!.focusWindow())
        assertTrue(Window.get(byId: 1)!.focusWindow())
        assertTrue(Window.get(byId: 6)!.focusWindow()) // The focus is on the other workspace, like on another monitor
        let expectedLayout = root.layoutDescription

        cacheClosedWindowIfNeeded()
        // Lock screen: the windows look dead and get rebound elsewhere in a different order
        for id: OpaqueWindowId in [5, 3, 1, 4, 2] {
            Window.get(byId: id)!.bind(to: b.rootTilingContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        }
        assertTrue(Window.get(byId: 6)!.focusWindow())

        assertTrue(try await restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: Window.get(byId: 1)!))

        assertEquals(a.rootTilingContainer.layoutDescription, expectedLayout)
        // Without the MRU replay the last bound window wins: 5
        assertEquals(a.mostRecentWindowRecursive?.windowId, 1)
        assertEquals(globalFocus.windowOrNil?.windowId, 6)
        assertEquals(b.mostRecentWindowRecursive?.windowId, 6)
    }
}
