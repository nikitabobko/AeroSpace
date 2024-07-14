import AppKit
import Common

struct MoveWorkspaceToMonitorCommand: Command {
    let args: MoveWorkspaceToMonitorCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        guard let focus = args.resolveFocusOrReportError(env, io) else { return false }
        let focusedWorkspace = focus.workspace
        let prevMonitor = focusedWorkspace.workspaceMonitor
        let sortedMonitors = sortedMonitors
        guard let index = sortedMonitors.firstIndex(where: { $0.rect.topLeftCorner == prevMonitor.rect.topLeftCorner }) else { return false }
        let targetMonitor = args.wrapAround
            ? sortedMonitors.get(wrappingIndex: args.target.val == .next ? index + 1 : index - 1)
            : sortedMonitors.getOrNil(atIndex: args.target.val == .next ? index + 1 : index - 1)
        guard let targetMonitor else { return false }

        if targetMonitor.setActiveWorkspace(focusedWorkspace) {
            let stubWorkspace = getStubWorkspace(for: prevMonitor)
            check(prevMonitor.setActiveWorkspace(stubWorkspace),
                  "getStubWorkspace generated incompatible stub workspace (\(stubWorkspace)) for the monitor (\(prevMonitor)")
            return true
        } else {
            return io.err("Can't move workspace '\(focusedWorkspace.name)' to monitor '\(targetMonitor.name)'. workspace-to-monitor-force-assignment doesn't allow it")
        }
    }
}
