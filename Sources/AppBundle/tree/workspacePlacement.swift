import Common
import Foundation

/// Durable placement: which monitor each workspace was last EXPLICITLY put on by the user.
///
/// Stored by monitor NAME, because monitor ids are not stable across reconnects (the virtual
/// displays on this machine re-enumerate as different units). Fail-soft by design: a missing,
/// unreadable or corrupt file means "no recorded placement" — never a crash, never a half-applied
/// state.
struct WorkspacePlacement: Codable, Equatable {
    var workspaceToMonitorName: [String: String] = [:]

    func monitorName(for workspace: String) -> String? { workspaceToMonitorName[workspace] }

    mutating func record(workspace: String, monitorName: String) {
        workspaceToMonitorName[workspace] = monitorName
    }
}

enum WorkspacePlacementStore {
    static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/AeroSpace/workspace-placement.json")
    }

    static func decode(_ data: Data) -> WorkspacePlacement {
        (try? JSONDecoder().decode(WorkspacePlacement.self, from: data)) ?? WorkspacePlacement()
    }

    static func encode(_ placement: WorkspacePlacement) -> Data? {
        try? JSONEncoder().encode(placement)
    }
}

/// Which monitor name should a workspace resolve to?
///
/// Precedence, and why:
///  1. recorded placement — the user put it there on purpose; this is what "it stays where I set
///     it" means. Only honoured while that monitor is actually connected.
///  2. force assignment from the config — a static default for workspaces the user never moved.
///  3. the monitor it is currently visible on — the present fact, used when neither of the above
///     says anything.
/// Returning nil leaves the caller's existing fallbacks (in-memory point, main monitor) intact.
///
/// Pure so the precedence itself can be unit tested without any real displays.
func resolvePlacementMonitorName(
    workspace: String,
    forceAssignedName: String?,
    visibleMonitorName: String?,
    persisted: WorkspacePlacement,
    availableMonitorNames: Set<String>,
) -> String? {
    if let recorded = persisted.monitorName(for: workspace), availableMonitorNames.contains(recorded) {
        return recorded
    }
    if let forceAssignedName {
        return forceAssignedName
    }
    if let visibleMonitorName {
        return visibleMonitorName
    }
    return nil
}

@MainActor var workspacePlacement: WorkspacePlacement = loadWorkspacePlacement()

@MainActor
private func loadWorkspacePlacement() -> WorkspacePlacement {
    guard let data = try? Data(contentsOf: WorkspacePlacementStore.url) else { return WorkspacePlacement() }
    return WorkspacePlacementStore.decode(data)
}

/// Records that the user explicitly put `workspace` on `monitor`, and persists it atomically.
/// Deliberately NOT called on every reveal: a display disconnect must not overwrite intent.
@MainActor
func recordUserPlacement(workspace: Workspace, monitor: MonitorInfo) {
    workspacePlacement.record(workspace: workspace.name, monitorName: monitor.name)
    let url = WorkspacePlacementStore.url
    do {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        if let data = WorkspacePlacementStore.encode(workspacePlacement) {
            try data.write(to: url, options: .atomic)
        }
    } catch {
        // Placement is a convenience. Never disturb the window manager because of it.
    }
}
