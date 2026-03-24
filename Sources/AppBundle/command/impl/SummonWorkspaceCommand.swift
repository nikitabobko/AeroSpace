import AppKit
import Common

struct SummonWorkspaceCommand: Command {
    let args: SummonWorkspaceCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let workspace = Workspace.get(byName: args.target.val.raw)
        let monitor = focus.workspace.workspaceMonitor
        if monitor.activeWorkspace == workspace {
            if !args.failIfNoop {
                io.err("Workspace '\(workspace.name)' is already visible on the focused monitor. Tip: use --fail-if-noop to exit with non-zero code")
            }
            return !args.failIfNoop
        }
        let prevMonitor = workspace.isVisible ? workspace.workspaceMonitor : nil
        if monitor.setActiveWorkspace(workspace) {
            if let prevMonitor {
                let stubWorkspace = getStubWorkspace(for: prevMonitor)
                check(
                    prevMonitor.setActiveWorkspace(stubWorkspace),
                    "getStubWorkspace generated incompatible stub workspace (\(stubWorkspace)) for the monitor (\(prevMonitor)",
                )
            }
            return workspace.focusWorkspace()
        } else {
            return io.err("Can't move workspace '\(workspace.name)' to monitor '\(monitor.name)'. workspace-to-monitor-force-assignment doesn't allow it")
        }
    }
}
