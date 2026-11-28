@testable import AppBundle
import Testing

@MainActor
@Suite(.serializedGlobally)
struct ClosedWindowsCacheTest {
    init() { setUpWorkspacesForTests() }

    @Test func testCachingKeepsMostRecentWindow() {
        let workspace = Workspace.get(byName: name)
        TestWindow.new(id: 6801, parent: workspace.rootTilingContainer)
        let mostRecent = TestWindow.new(id: 6802, parent: workspace.rootTilingContainer)
        TestWindow.new(id: 6803, parent: workspace.rootTilingContainer)
        #expect(mostRecent.focusWindow())

        cacheClosedWindowIfNeeded()

        #expect(workspace.toLiveFocus().windowOrNil === mostRecent)
    }
}
