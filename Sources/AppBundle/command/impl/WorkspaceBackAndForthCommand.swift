import AppKit
import Common

struct WorkspaceBackAndForthCommand: Command {
    let args: WorkspaceBackAndForthCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        return prevFocusedWorkspace?.focusWorkspace() != nil
    }
}
