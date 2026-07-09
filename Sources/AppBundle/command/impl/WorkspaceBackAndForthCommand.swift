import AppKit
import Common

struct WorkspaceBackAndForthCommand: Command {
    let args: WorkspaceBackAndForthCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let workspace = prevFocusedWorkspace else { return .fail }
        let didFocus = workspace.focusWorkspace()
        if didFocus {
            protectFocusAfterWorkspaceSwitch(workspaceName: workspace.name)
        }
        return .from(bool: didFocus)
    }
}
