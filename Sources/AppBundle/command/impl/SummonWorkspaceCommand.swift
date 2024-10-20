import AppKit
import Common

struct SummonWorkspaceCommand: Command {
    let args: SummonWorkspaceCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        let workspace = Workspace.get(byName: args.target.val.raw)

        let curMonitor = focus.workspace.workspaceMonitor

        let monitor = focus.workspace.forceAssignedMonitor ?? curMonitor
        if monitor.activeWorkspace == workspace {
            io.err("Workspace '\(workspace.name)' is already visible on the focused monitor. Tip: use --fail-if-noop to exit with non-zero code")
            return !args.failIfNoop
        }

        let onMonitor = monitors.first { $0.activeWorkspace == workspace }
        if let onMonitor = onMonitor {
            if workspace.forceAssignedMonitor?.monitorId == onMonitor.monitorId {
                io.err("Workspace '\(workspace.name)' is already visible on a monitor, returning")
                return !args.failIfNoop
            }
            if curMonitor.activeWorkspace.forceAssignedMonitor != nil {
                io.err("Current Monitor has a pinned workspace, can't swap - returning")
                return !args.failIfNoop
            }

            _ = onMonitor.setActiveWorkspace(curMonitor.activeWorkspace)
        }

        if isValidAssignment(workspace: workspace, monitor: monitor) {
            _ = monitor.setActiveWorkspace(workspace)
            return monitor.activeWorkspace.focusWorkspace()
        } else {
            return workspace.forceAssignedMonitor?.setActiveWorkspace(workspace) != nil
        }
    }
}
