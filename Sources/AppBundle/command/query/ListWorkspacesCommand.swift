import AppKit
import Common

struct ListWorkspacesCommand: Command {
    let args: ListWorkspacesCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        var result: [Workspace] = Workspace.all
        if let visible = args.visible {
            result = result.filter { $0.isVisible == visible }
        }
        if !args.onMonitors.isEmpty {
            let monitors: Set<CGPoint> = args.onMonitors.resolveMonitors(state)
            if monitors.isEmpty { return false }
            result = result.filter { monitors.contains($0.workspaceMonitor.rect.topLeftCorner) }
        }
        if let empty = args.empty {
            result = result.filter { $0.isEffectivelyEmpty == empty }
        }
        switch result.map({ AeroObj.workspace($0) }).format(args.format) {
            case .success(let lines):
                state.stdout += lines
                return true
            case .failure(let msg):
                return state.failCmd(msg: msg)
        }
    }
}

extension [MonitorId] {
    func resolveMonitors(_ state: CommandMutableState) -> Set<CGPoint> {
        var requested: Set<CGPoint> = []
        let sortedMonitors = sortedMonitors
        for id in self {
            let resolved = id.resolve(state, sortedMonitors: sortedMonitors)
            if resolved.isEmpty {
                return []
            }
            for monitor in resolved {
                requested.insert(monitor.rect.topLeftCorner)
            }
        }
        return requested
    }
}

extension MonitorId {
    func resolve(_ state: CommandMutableState, sortedMonitors: [Monitor]) -> [Monitor] {
        switch self {
            case .focused:
                return [focus.workspace.workspaceMonitor]
            case .mouse:
                return [mouseLocation.monitorApproximation]
            case .all:
                return monitors
            case .index(let index):
                if let monitor = sortedMonitors.getOrNil(atIndex: index) {
                    return [monitor]
                } else {
                    state.stderr.append("Invalid monitor ID: \(index + 1)")
                    return []
                }
        }
    }
}
