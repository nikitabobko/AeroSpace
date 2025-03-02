import AppKit
import Common

struct ListWorkspacesCommand: Command {
    let args: ListWorkspacesCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        var result: [Workspace] = Workspace.all
        if let visible = args.filteringOptions.visible {
            result = result.filter { $0.isVisible == visible }
        }
        if !args.filteringOptions.onMonitors.isEmpty {
            let monitors: Set<CGPoint> = args.filteringOptions.onMonitors.resolveMonitors(io)
            if monitors.isEmpty { return false }
            result = result.filter { monitors.contains($0.workspaceMonitor.rect.topLeftCorner) }
        }
        if let empty = args.filteringOptions.empty {
            result = result.filter { $0.isEffectivelyEmpty == empty }
        }

        if args.outputOnlyCount {
            return io.out("\(result.count)")
        } else {
            let list = result.map { AeroObj.workspace($0) }
            if args.json {
                return switch list.formatToJson(args.format, ignoreRightPaddingVar: args._format.isEmpty) {
                    case .success(let json): io.out(json)
                    case .failure(let msg): io.err(msg)
                }
            } else {
                return switch list.format(args.format) {
                    case .success(let lines): io.out(lines)
                    case .failure(let msg): io.err(msg)
                }
            }
        }
    }
}

extension [MonitorId] {
    @MainActor func resolveMonitors(_ io: CmdIo) -> Set<CGPoint> {
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
    @MainActor func resolve(_ io: CmdIo, sortedMonitors: [Monitor]) -> [Monitor] {
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
