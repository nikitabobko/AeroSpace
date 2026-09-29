import AppKit
import Common

struct ListWorkspacesCommand: Command {
    let args: ListWorkspacesCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        var result: [Workspace] = Workspace.all
        if let visible = args.filteringFlags.visible {
            result = result.filter { $0.isVisible == visible }
        }
        if !args.filteringFlags.onMonitors.isEmpty {
            let monitors: Set<CGPoint> = args.filteringFlags.onMonitors.resolveMonitors(io)
            if monitors.isEmpty { return .fail }
            result = result.filter { monitors.contains($0.workspaceMonitorInfo.rect.topLeftCorner) }
        }
        if let empty = args.filteringFlags.empty {
            result = result.filter { $0.isEffectivelyEmpty == empty }
        }

        lazy var list = result.map() { AeroObj.workspace($0) }
        return switch true {
            case args.outputOnlyCount:
                .succ(io.out("\(result.count)"))
            case args.json:
                switch list.formatToJson(args.format, ignoreRightPaddingVar: args._format.isEmpty) {
                    case .success(let json): .succ(io.out(json))
                    case .failure(let msg): .fail(io.err(msg))
                }
            default:
                switch list.format(args.format) {
                    case .success(let lines): .succ(io.out(lines))
                    case .failure(let msg): .fail(io.err(msg.map(\.description).joinErrors()))
                }
        }
    }
}

extension [MonitorId] {
    @MainActor func resolveMonitors(_ io: CmdIo) -> Set<CGPoint> {
        var requested: Set<CGPoint> = []
        let sortedMonitors = globalSortedMonitorInfos
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
    @MainActor func resolve(_ io: CmdIo, sortedMonitors: [MonitorInfo]) -> [MonitorInfo] {
        switch self {
            case .focused:
                return [globalFocus.workspace.workspaceMonitorInfo]
            case .mouse:
                return [mouseLocation.monitorApproximation]
            case .all:
                return globalUnsortedMonitorInfos
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
