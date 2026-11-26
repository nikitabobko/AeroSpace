@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct HideInvisibleWorkspacesTest {
    init() { setUpWorkspacesForTests() }

    // layoutWorkspaces iterates over a snapshot of Workspace.all and has suspension points. Other sessions can garbage
    // collect a workspace in the meantime. Such a workspace is unbound from the tree and has no monitor
    @Test func testGarbageCollectedWorkspaceInSnapshotDoesNotCrash() async throws {
        let garbage = Workspace.get(byName: "garbage")
        let snapshot = Workspace.all
        Workspace.garbageCollectUnusedWorkspaces()
        assertNil(garbage.nodeMonitorInfo)
        assertTrue(snapshot.contains(garbage))

        try await hideInvisibleWorkspaces(snapshot, [:])
    }
}
