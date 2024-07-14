import AppKit
import Common

struct ListWorkspacesCommand: Command {
    let args: ListWorkspacesCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        var result: [Workspace] = Workspace.all
        if let visible = args.visible {
            result = result.filter { $0.isVisible == visible }
        }
        if !args.onMonitors.isEmpty {
            let monitors: Set<CGPoint> = args.onMonitors.resolveMonitors(io)
            if monitors.isEmpty { return false }
            result = result.filter { monitors.contains($0.workspaceMonitor.rect.topLeftCorner) }
        }
        if let empty = args.empty {
            result = result.filter { $0.isEffectivelyEmpty == empty }
        }
        return switch result.map({ AeroObj.workspace($0) }).format(args.format) {
            case .success(let lines): io.out(lines)
            case .failure(let msg): io.err(msg)
        }
    }
}

extension [MonitorId] {
    func resolveMonitors(_ io: CmdIo) -> Set<CGPoint> {
        var requested: Set<CGPoint> = []
        let sortedMonitors = sortedMonitors
        for id in self {
            let resolved = id.resolve(io, sortedMonitors: sortedMonitors)
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
    func resolve(_ io: CmdIo, sortedMonitors: [Monitor]) -> [Monitor] {
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
                    io.err("Invalid monitor ID: \(index + 1)")
                    return []
                }
        }
    }
}
