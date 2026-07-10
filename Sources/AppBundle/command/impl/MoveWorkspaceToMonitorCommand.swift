import AppKit
import Common

struct MoveWorkspaceToMonitorCommand: Command {
    let args: MoveWorkspaceToMonitorCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        let focusedWorkspace = target.workspace
        let prevMonitor = focusedWorkspace.workspaceMonitorInfo

        switch args.target.val.resolve(target.workspace.workspaceMonitorInfo, wrapAround: args.wrapAround) {
            case .success(let targetMonitor):
                if targetMonitor.monitorId_oneBased == prevMonitor.monitorId_oneBased {
                    return .succ
                }
                if targetMonitor.setVisibleWorkspace(focusedWorkspace) {
                    let stubWorkspace = getStubWorkspace(for: prevMonitor)
                    check(
                        prevMonitor.setVisibleWorkspace(stubWorkspace),
                        "getStubWorkspace generated incompatible stub workspace (\(stubWorkspace)) for the monitor (\(prevMonitor)",
                    )
                    return .succ
                } else {
                    return .fail(io.err(
                        "Can't move workspace '\(focusedWorkspace.name)' to monitor '\(targetMonitor.name)'. workspace-to-monitor-force-assignment doesn't allow it",
                    ))
                }
            case .failure(let msg):
                return .fail(io.err(msg))
        }
    }
}
