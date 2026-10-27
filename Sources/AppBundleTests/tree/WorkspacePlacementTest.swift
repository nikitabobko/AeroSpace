@testable import AppBundle
import Common
import XCTest

@MainActor
final class WorkspacePlacementTest: XCTestCase {
    private let all: Set<String> = ["Monitor A", "Monitor B", "Monitor C"]

    func testRecordedPlacementWinsWhenThatMonitorIsConnected() {
        var persisted = WorkspacePlacement()
        persisted.record(workspace: "E", monitorName: "Monitor B")
        assertEquals(
            resolvePlacementMonitorName(
                workspace: "E",
                forceAssignedName: "Monitor A", // a stale config pin must lose
                visibleMonitorName: "Monitor C",
                persisted: persisted,
                availableMonitorNames: all,
            ),
            "Monitor B",
        )
    }

    func testRecordedPlacementIgnoredWhenThatMonitorIsGone() {
        var persisted = WorkspacePlacement()
        persisted.record(workspace: "E", monitorName: "Monitor B")
        assertEquals(
            resolvePlacementMonitorName(
                workspace: "E",
                forceAssignedName: nil,
                visibleMonitorName: "Monitor C",
                persisted: persisted,
                availableMonitorNames: ["Monitor A", "Monitor C"],
            ),
            "Monitor C", // falls through instead of resolving to a monitor that isn't there
        )
    }

    func testConfigPinIsTheDefaultForNeverMovedWorkspaces() {
        assertEquals(
            resolvePlacementMonitorName(
                workspace: "3",
                forceAssignedName: "Monitor B",
                visibleMonitorName: "Monitor C",
                persisted: WorkspacePlacement(),
                availableMonitorNames: all,
            ),
            "Monitor B",
        )
    }

    func testVisibleMonitorUsedWhenNothingRecordedOrAssigned() {
        assertEquals(
            resolvePlacementMonitorName(
                workspace: "A",
                forceAssignedName: nil,
                visibleMonitorName: "Monitor C",
                persisted: WorkspacePlacement(),
                availableMonitorNames: all,
            ),
            "Monitor C",
        )
    }

    func testNothingKnownReturnsNilSoExistingFallbacksStay() {
        assertEquals(
            resolvePlacementMonitorName(
                workspace: "A",
                forceAssignedName: nil,
                visibleMonitorName: nil,
                persisted: WorkspacePlacement(),
                availableMonitorNames: all,
            ),
            nil,
        )
    }

    func testRecordOverwritesPreviousPlacement() {
        var persisted = WorkspacePlacement()
        persisted.record(workspace: "E", monitorName: "Monitor B")
        persisted.record(workspace: "E", monitorName: "Monitor A")
        assertEquals(persisted.monitorName(for: "E"), "Monitor A")
    }

    func testDecodeOfGarbageIsEmptyAndDoesNotThrow() {
        let garbage = "this is not json{{{".data(using: .utf8)!
        assertEquals(WorkspacePlacementStore.decode(garbage), WorkspacePlacement())
    }

    func testEncodeDecodeRoundTrip() {
        var persisted = WorkspacePlacement()
        persisted.record(workspace: "E", monitorName: "Monitor B")
        persisted.record(workspace: "3", monitorName: "Monitor C")
        let data = WorkspacePlacementStore.encode(persisted)!
        assertEquals(WorkspacePlacementStore.decode(data), persisted)
    }
}
