import AppKit
import Common

struct ListMonitorsCommand: Command {
    let args: ListMonitorsCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        let focus = focus
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
            let list = result.map { AeroObj.monitor($0) }
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
