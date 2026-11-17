@testable import AppBundle
import Common
import Foundation
import Testing

private final class NativeTabTestIds {
    private var next: UInt64 = 0
    func make() -> OpaqueWindowId { next += 1; return OpaqueWindowId(next) }
}

private func tabSnapshot(_ observations: [(UInt32, UUID?)], retained: Set<UInt32>) -> NativeTabSnapshot {
    .available(observations.map { NativeTabObservation(nativeWindowId: $0.0, group: $0.1) }, retainedNativeWindowIds: retained)
}

struct NativeTabWindowIdsTest {
    @Test func testSelectionRetainsOneLogicalWindow() throws {
        let group = UUID(), ids = NativeTabTestIds()
        var mapping = NativeTabWindowIds()
        try mapping.reconcile(tabSnapshot([(10, group)], retained: [10]), makeId: ids.make, checkCancellation: {})
        let logical = try #require(mapping.backward[10])
        try mapping.reconcile(tabSnapshot([(11, group)], retained: [10, 11]), makeId: ids.make, checkCancellation: {})
        #expect(mapping.backward[11] == logical)
        #expect(mapping.backward[10] == nil)
        #expect(mapping.logicalWindows([10: .invisible, 11: .alive])[logical] == .alive)
        try mapping.reconcile(tabSnapshot([(10, group)], retained: [10, 11]), makeId: ids.make, checkCancellation: {})
        #expect(mapping.backward[10] == logical)
        #expect(mapping.backward[11] == nil)
        #expect(mapping.forward.count == 1)
    }

    @Test func testMissingWindowAndNewIndependentWindowAreNotTabs() throws {
        let ids = NativeTabTestIds()
        var mapping = NativeTabWindowIds()
        try mapping.reconcile(tabSnapshot([(10, nil)], retained: [10]), makeId: ids.make, checkCancellation: {})
        let original = mapping.backward[10]
        try mapping.reconcile(tabSnapshot([(20, nil)], retained: [10, 20]), makeId: ids.make, checkCancellation: {})
        #expect(mapping.backward[10] == original)
        #expect(mapping.backward[20] != original)
        #expect(mapping.logicalWindows([10: .alive, 20: .alive]).count == 2)
    }

    @Test func testSimultaneousSelectionsInTwoGroupsStayIndependent() throws {
        let a = UUID(), b = UUID(), ids = NativeTabTestIds()
        var mapping = NativeTabWindowIds()
        try mapping.reconcile(tabSnapshot([(10, a), (20, b)], retained: [10, 20]), makeId: ids.make, checkCancellation: {})
        let first = mapping.backward[10], second = mapping.backward[20]
        try mapping.reconcile(tabSnapshot([(11, a), (21, b)], retained: [10, 11, 20, 21]), makeId: ids.make, checkCancellation: {})
        #expect(mapping.backward[11] == first)
        #expect(mapping.backward[21] == second)
        #expect(first != second)
        #expect(mapping.backward[10] == nil)
        #expect(mapping.backward[20] == nil)
    }

    @Test(arguments: [false, true]) func testSelectedTabDetachesWhileGroupSurvives(reverseOrder: Bool) throws {
        let group = UUID(), ids = NativeTabTestIds()
        var mapping = NativeTabWindowIds()
        try mapping.reconcile(tabSnapshot([(10, group)], retained: [10]), makeId: ids.make, checkCancellation: {})
        try mapping.reconcile(tabSnapshot([(12, group)], retained: [10, 12]), makeId: ids.make, checkCancellation: {})
        try mapping.reconcile(tabSnapshot([(11, group)], retained: [10, 11, 12]), makeId: ids.make, checkCancellation: {})
        let original = mapping.backward[11]
        var observations: [(UInt32, UUID?)] = [(10, group), (11, nil)]
        if reverseOrder { observations.reverse() }
        try mapping.reconcile(tabSnapshot(observations, retained: [10, 11, 12]), makeId: ids.make, checkCancellation: {})
        #expect(mapping.backward[10] == original)
        #expect(mapping.backward[11] != original)
        #expect(mapping.backward[10] != mapping.backward[11])
        #expect(mapping.logicalWindows([10: .alive, 11: .alive, 12: .invisible]).count == 2)
    }

    @Test func testDissolvedGroupKeepsCurrentRepresentativeIndependent() throws {
        let group = UUID(), ids = NativeTabTestIds()
        var mapping = NativeTabWindowIds()
        try mapping.reconcile(tabSnapshot([(10, group)], retained: [10]), makeId: ids.make, checkCancellation: {})
        try mapping.reconcile(tabSnapshot([(11, group)], retained: [10, 11]), makeId: ids.make, checkCancellation: {})
        let current = mapping.backward[11]
        try mapping.reconcile(tabSnapshot([(10, nil), (11, nil)], retained: [10, 11]), makeId: ids.make, checkCancellation: {})
        #expect(mapping.backward[11] == current)
        #expect(mapping.backward[10] != current)
        #expect(mapping.backward[10] != mapping.backward[11])
    }

    @Test func testClosedBackgroundTabDoesNotStealSurvivorsIdentity() throws {
        let group = UUID(), ids = NativeTabTestIds()
        var mapping = NativeTabWindowIds()
        try mapping.reconcile(tabSnapshot([(10, group)], retained: [10]), makeId: ids.make, checkCancellation: {})
        try mapping.reconcile(tabSnapshot([(11, group)], retained: [10, 11]), makeId: ids.make, checkCancellation: {})
        let survivor = mapping.backward[11]
        try mapping.reconcile(tabSnapshot([(11, nil)], retained: [11]), makeId: ids.make, checkCancellation: {})
        #expect(mapping.backward[11] == survivor)
        #expect(mapping.logicalWindows([11: .alive]).count == 1)
    }

    @Test func testOffSpaceSurvivingGroupKeepsItsLogicalWindow() throws {
        let group = UUID(), ids = NativeTabTestIds()
        var mapping = NativeTabWindowIds()
        try mapping.reconcile(tabSnapshot([(10, group)], retained: [10]), makeId: ids.make, checkCancellation: {})
        try mapping.reconcile(tabSnapshot([(11, group)], retained: [10, 11]), makeId: ids.make, checkCancellation: {})
        let original = mapping.backward[11]
        try mapping.reconcile(tabSnapshot([(11, nil)], retained: [10, 11]), makeId: ids.make, checkCancellation: {})
        #expect(mapping.backward[10] == original)
        #expect(mapping.backward[11] != original)
        try mapping.reconcile(tabSnapshot([(10, group)], retained: [10, 11]), makeId: ids.make, checkCancellation: {})
        #expect(mapping.backward[10] == original)
    }

    @Test func testLateDiscoveredMemberCollapsesItsPriorIndependentIdentity() throws {
        let group = UUID(), ids = NativeTabTestIds()
        var mapping = NativeTabWindowIds()
        try mapping.reconcile(tabSnapshot([(10, nil)], retained: [10]), makeId: ids.make, checkCancellation: {})
        let previouslyIndependent = mapping.backward[10]
        try mapping.reconcile(tabSnapshot([(11, group)], retained: [10, 11]), makeId: ids.make, checkCancellation: {})
        let groupId = mapping.backward[11]
        #expect(groupId != previouslyIndependent)
        try mapping.reconcile(tabSnapshot([(10, group)], retained: [10, 11]), makeId: ids.make, checkCancellation: {})
        #expect(mapping.backward[10] == groupId)
        #expect(mapping.forward[try #require(previouslyIndependent)] == nil)
        #expect(mapping.backward[11] == nil)
    }

    @Test func testJoiningAnotherGroupDoesNotMergeTheTwoLogicalIds() throws {
        let a = UUID(), b = UUID(), ids = NativeTabTestIds()
        var mapping = NativeTabWindowIds()
        try mapping.reconcile(tabSnapshot([(10, a), (20, b)], retained: [10, 20]), makeId: ids.make, checkCancellation: {})
        let first = mapping.backward[10], second = mapping.backward[20]
        try mapping.reconcile(tabSnapshot([(11, a), (20, b)], retained: [10, 11, 20]), makeId: ids.make, checkCancellation: {})
        try mapping.reconcile(tabSnapshot([(10, a), (11, b)], retained: [10, 11, 20]), makeId: ids.make, checkCancellation: {})
        #expect(mapping.backward[10] == first)
        #expect(mapping.backward[11] == second)
        #expect(first != second)
        #expect(mapping.backward[20] == nil)
    }

    @Test func testUnavailableSnapshotDoesNotMutateEitherDirection() throws {
        let group = UUID(), ids = NativeTabTestIds()
        var mapping = NativeTabWindowIds()
        try mapping.reconcile(tabSnapshot([(10, group)], retained: [10]), makeId: ids.make, checkCancellation: {})
        let before = mapping.forward
        #expect(try !mapping.reconcile(.unavailable, makeId: ids.make, checkCancellation: {}))
        #expect(mapping.forward == before)
        #expect(mapping.backward[10] == before.first?.key)
        // A newly selected native tab is not an independent logical window
        // merely because its group could not be read in this refresh.
        let refreshed = mapping.logicalWindows([10: .invisible, 11: .alive])
        #expect(refreshed.count == 1)
        #expect(mapping.backward[11] == nil)
        #expect(refreshed[try #require(mapping.backward[10])] == .invisible)
    }

    @Test func testUnreadableSurvivorDoesNotDeleteClosedRepresentativesTreeSlot() throws {
        let group = UUID(), ids = NativeTabTestIds()
        var mapping = NativeTabWindowIds()
        try mapping.reconcile(tabSnapshot([(10, group)], retained: [10]), makeId: ids.make, checkCancellation: {})
        try mapping.reconcile(tabSnapshot([(11, group)], retained: [10, 11]), makeId: ids.make, checkCancellation: {})
        let original = try #require(mapping.backward[11])
        try mapping.reconcile(.unavailable, makeId: ids.make, checkCancellation: {})
        #expect(mapping.logicalWindows([10: .alive])[original] == .invisible)
        #expect(mapping.backward[10] == nil)
        try mapping.reconcile(tabSnapshot([(10, nil)], retained: [10]), makeId: ids.make, checkCancellation: {})
        #expect(mapping.logicalWindows([10: .alive]).count == 1)
        #expect(mapping.backward[10] == original)
    }

    @Test func testCancellationBeforeCommitDoesNotMutateMappingsOrMembership() throws {
        let group = UUID(), ids = NativeTabTestIds()
        var mapping = NativeTabWindowIds()
        try mapping.reconcile(tabSnapshot([(10, group)], retained: [10]), makeId: ids.make, checkCancellation: {})
        let before = mapping.forward
        var checks = 0
        #expect(throws: CancellationError.self) {
            try mapping.reconcile(tabSnapshot([(11, group)], retained: [10, 11]), makeId: ids.make, checkCancellation: {
                checks += 1
                if checks == 2 { throw CancellationError() }
            })
        }
        #expect(mapping.forward == before)
        #expect(mapping.backward[11] == nil)
        #expect(mapping.logicalWindows([10: .alive, 11: .alive]).count == 1)
    }

    @Test func testAmbiguousSelectedRepresentativesDoNotGuessOrAllocate() throws {
        let group = UUID(), ids = NativeTabTestIds()
        var mapping = NativeTabWindowIds()
        try mapping.reconcile(tabSnapshot([(10, group)], retained: [10]), makeId: ids.make, checkCancellation: {})
        let before = mapping.forward
        #expect(try !mapping.reconcile(tabSnapshot([(10, group), (11, group)], retained: [10, 11]), makeId: ids.make, checkCancellation: {}))
        #expect(mapping.forward == before)
        #expect(mapping.backward[11] == nil)
        #expect(mapping.logicalWindows([10: .alive, 11: .alive]).count == 1)
    }
}

@MainActor
@Suite(.serializedGlobally)
struct NativeTabTreeIdentityTest {
    init() { setUpWorkspacesForTests() }

    @Test func testSelectionKeepsExistingTreeAndMovedWorkspace() throws {
        let group = UUID(), ids = NativeTabTestIds()
        var mapping = NativeTabWindowIds()
        try mapping.reconcile(tabSnapshot([(10, group)], retained: [10]), makeId: ids.make, checkCancellation: {})
        let id = try #require(mapping.backward[10])
        let original = Workspace.get(byName: "original")
        let destination = Workspace.get(byName: "destination")
        let window = TestWindow.new(id: id, parent: original.rootTilingContainer)
        #expect(moveWindowToWorkspace(window, destination, CmdIoImpl.emptyStdinIgnoringOut, focusFollowsWindow: false, failIfNoop: false) == .succ)
        try mapping.reconcile(tabSnapshot([(11, group)], retained: [10, 11]), makeId: ids.make, checkCancellation: {})
        let selected = try #require(mapping.backward[11])
        #expect(Window.get(byId: selected) === window)
        #expect(window.nodeWorkspace === destination)
        #expect(destination.rootTilingContainer.children.count == 1)
        #expect(original.isEffectivelyEmpty)
    }
}
