import AppKit
import Common

struct ListMonitorsCommand: Command {
    let args: ListMonitorsCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        guard let focus = args.resolveFocusOrReportError(env, io) else { return false }
        var result = sortedMonitors
        if let focused = args.focused {
            result = result.filter { (monitor) in (monitor.activeWorkspace == focus.workspace) == focused }
        }
        if let mouse = args.mouse {
            let mouseWorkspace = mouseLocation.monitorApproximation.activeWorkspace
            result = result.filter { (monitor) in (monitor.activeWorkspace == mouseWorkspace) == mouse }
        }

        if args.outputOnlyCount {
            return io.out("\(result.count)")
        } else {
            return switch result.map({ AeroObj.monitor($0) }).format(args.format) {
                case .success(let lines): io.out(lines)
                case .failure(let msg): io.err(msg)
            }
        }
    }
}
