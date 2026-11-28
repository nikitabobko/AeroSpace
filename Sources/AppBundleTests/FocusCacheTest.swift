@testable import AppBundle
import Testing

@MainActor
@Suite(.serializedGlobally)
struct FocusCacheTest {
    init() {
        setUpWorkspacesForTests()
    }

    @Test func ignoresStaleFocusFromAppUntilFocusTransactionSettles() {
        defer { cancelNativeFocusTransaction() }
        let expectedWorkspace = Workspace.get(byName: "expected")
        let staleWorkspace = Workspace.get(byName: "stale")
        let expectedWindow = TestWindow.new(id: 1, parent: expectedWorkspace.rootTilingContainer)
        let staleWindow = TestWindow.new(id: 2, parent: staleWorkspace.rootTilingContainer)

        #expect(expectedWindow.focusWindow())
        expectNativeFocus(expectedWindow)

        updateFocusCache(staleWindow)
        #expect(globalFocus.windowOrNil === expectedWindow)
        #expect(globalFocus.workspace === expectedWorkspace)

        updateFocusCache(expectedWindow)
        updateFocusCache(staleWindow)
        #expect(globalFocus.windowOrNil === expectedWindow)
        #expect(globalFocus.workspace === expectedWorkspace)
    }
}
