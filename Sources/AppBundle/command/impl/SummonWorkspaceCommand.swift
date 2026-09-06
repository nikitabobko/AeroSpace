import AppKit
import Common

struct SummonWorkspaceCommand: Command {
    let args: SummonWorkspaceCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        let workspace = Workspace.get(byName: args.target.val.raw)
        let monitor = focus.workspace.workspaceMonitor
        if monitor.activeWorkspace == workspace {
            return switch args.failIfNoop {
                case true: .fail
                case false:
                    .succ(io.err("Workspace '\(workspace.name)' is already visible on the focused monitor. Tip: use --fail-if-noop to exit with non-zero code"))
            }
        }
        if workspace.isVisible {
            // The workspace is already visible on another monitor
            let otherMonitor = workspace.workspaceMonitor
            switch args.whenVisible {
                case .swap:
                    let currentWorkspace = monitor.activeWorkspace
                    if otherMonitor.setActiveWorkspace(currentWorkspace) && monitor.setActiveWorkspace(workspace) {
                        return .from(bool: workspace.focusWorkspace())
                    } else {
                        return .fail(io.err("Can't swap workspaces due to workspace-to-monitor-force-assignment restrictions"))
                    }
                case .focus:
                    return .from(bool: workspace.focusWorkspace())
            }
        }
        if monitor.setActiveWorkspace(workspace) {
            return .from(bool: workspace.focusWorkspace())
        } else {
            return .fail(io.err("Can't move workspace '\(workspace.name)' to monitor '\(monitor.name)'. workspace-to-monitor-force-assignment doesn't allow it"))
        }
    }
}
