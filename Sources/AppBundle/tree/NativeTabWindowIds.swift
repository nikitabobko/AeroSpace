import Common
import Foundation

struct NativeTabObservation: Sendable {
    let nativeWindowId: UInt32
    let group: UUID?
}

enum NativeTabSnapshot: Sendable {
    case unavailable
    case available([NativeTabObservation], retainedNativeWindowIds: Set<UInt32>)
}

// The selected NSWindow changes when an AppKit tab changes. The logical
// window, and therefore its existing tree position and workspace, do not.
struct NativeTabWindowIds {
    private var ids = BiDictionary<OpaqueWindowId, UInt32>()
    private var membership: [UInt32: UUID] = [:]
    private var groups: [UUID: OpaqueWindowId] = [:]

    var forward: [OpaqueWindowId: UInt32] { ids.forward }
    var backward: [UInt32: OpaqueWindowId] { ids.backward }

    func logicalWindows(_ nativeWindows: [UInt32: WindowLifeStatus]) -> [OpaqueWindowId: WindowLifeStatus] {
        var result: [OpaqueWindowId: WindowLifeStatus] = [:]
        for (nativeId, status) in nativeWindows {
            if let id = ids.backward[nativeId] {
                result[id] = status
            } else if let id = membership[nativeId].flatMap({ groups[$0] }), result[id] == nil {
                // Keep the group's tombstone if its representative closed and
                // a surviving member cannot yet provide a fresh AX snapshot.
                result[id] = .invisible
            }
        }
        return result
    }

    private mutating func register(_ nativeId: UInt32, makeId: () -> OpaqueWindowId) {
        guard ids.backward[nativeId] == nil else { return }
        ids.put(makeId(), nativeId)
    }

    @discardableResult
    mutating func reconcile(
        _ snapshot: NativeTabSnapshot,
        makeId: () -> OpaqueWindowId,
        checkCancellation: () throws -> Void,
    ) throws -> Bool {
        try checkCancellation()
        guard case .available(let observations, let retainedNativeWindowIds) = snapshot else { return false }
        var selected: [UUID: UInt32] = [:]
        for observation in observations {
            if let group = observation.group {
                // A transition exposing two representatives is not yet an
                // authoritative snapshot of the selected native window.
                guard selected[group] == nil || selected[group] == observation.nativeWindowId else { return false }
                selected[group] = observation.nativeWindowId
            }
        }
        var next = self
        next.membership = next.membership.filter { retainedNativeWindowIds.contains($0.key) }
        for observation in observations {
            next.membership[observation.nativeWindowId] = observation.group
        }
        for (group, logicalId) in next.groups {
            let members = next.membership.filter { $0.value == group }.map(\.key)
            if members.isEmpty {
                if let representative = next.ids.forward[logicalId], !retainedNativeWindowIds.contains(representative) {
                    let survivors = membership.filter { $0.value == group && retainedNativeWindowIds.contains($0.key) }.map(\.key)
                    if survivors.count == 1, let survivor = survivors.first {
                        next.ids.put(logicalId, survivor)
                    }
                }
                // The group dissolved. Its last representative remains the
                // same independent window; other detached tabs get new IDs.
                next.groups[group] = nil
            } else if selected[group] == nil,
                      let representative = next.ids.forward[logicalId],
                      next.membership[representative] != group,
                      let backgroundMember = members.min()
            {
                // Keep an off-Space group's existing tombstone when its
                // representative detaches or joins another group.
                next.ids.put(logicalId, backgroundMember)
            }
        }
        var reserved = Set(next.groups.values)
        // Resolve surviving groups before standalone windows. If the selected
        // tab detaches from three tabs, the remaining group keeps its tree slot.
        for (group, nativeId) in selected.sorted(by: { $0.value < $1.value }) {
            let existing = next.ids.backward[nativeId].flatMap { reserved.contains($0) ? nil : $0 }
            let logicalId = next.groups[group] ?? existing ?? makeId()
            next.groups[group] = logicalId
            reserved.insert(logicalId)
            next.ids.put(logicalId, nativeId)
        }
        for observation in observations where observation.group == nil {
            next.register(observation.nativeWindowId, makeId: makeId)
        }
        try checkCancellation()
        self = next
        return true
    }
}
