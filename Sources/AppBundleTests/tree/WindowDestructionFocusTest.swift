@testable import AppBundle
import Testing

@MainActor
@Suite(.serializedGlobally)
struct WindowDestructionFocusTest {
    init() { setUpWorkspacesForTests() }

    @Test func testNativeFocusWhenAnotherAppIsFocused() {
        let workspace = Workspace.get(byName: "a")
        #expect(mustNativeFocusAfterWindowDestruction(
            focusedAppPid: 2, focusedWorkspace: workspace, deadWindowAppPid: 1, deadWindowWorkspace: workspace,
        ))
    }

    @Test func testNativeFocusWhenNoWindowIsFocused() {
        let workspace = Workspace.get(byName: "a")
        #expect(mustNativeFocusAfterWindowDestruction(
            focusedAppPid: nil, focusedWorkspace: workspace, deadWindowAppPid: 1, deadWindowWorkspace: workspace,
        ))
    }

    // https://github.com/nikitabobko/AeroSpace/issues/201
    @Test func testNoNativeFocusWhenSameAppIsFocusedOnDeadWindowWorkspace() {
        let workspace = Workspace.get(byName: "a")
        #expect(!mustNativeFocusAfterWindowDestruction(
            focusedAppPid: 1, focusedWorkspace: workspace, deadWindowAppPid: 1, deadWindowWorkspace: workspace,
        ))
    }

    // macOS hands the focus to a window of the same app on another workspace, e.g. on another monitor.
    // AeroSpace switches back to the dead window's workspace, so macOS must follow.
    @Test func testNativeFocusWhenSameAppIsFocusedOnAnotherWorkspace() {
        #expect(mustNativeFocusAfterWindowDestruction(
            focusedAppPid: 1,
            focusedWorkspace: Workspace.get(byName: "b"),
            deadWindowAppPid: 1,
            deadWindowWorkspace: Workspace.get(byName: "a"),
        ))
    }
}
