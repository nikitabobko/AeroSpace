import AppKit
import Common

struct ListMonitorsCommand: Command {
    let args: ListMonitorsCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        var result: [(Int, Monitor)] = sortedMonitors.withIndex
        if let focused = args.focused {
            result = result.filter { (_, monitor) in (monitor.activeWorkspace == Workspace.focused) == focused }
        }
        if let mouse = args.mouse {
            let mouseWorkspace = mouseLocation.monitorApproximation.activeWorkspace
            result = result.filter { (_, monitor) in (monitor.activeWorkspace == mouseWorkspace) == mouse }
        }
        state.stdout += result
            .map { (index, monitor) in
                [String(index + 1), monitor.name]
            }
            .toPaddingTable()
        return true
    }
}
