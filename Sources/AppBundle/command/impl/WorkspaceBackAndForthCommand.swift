import AppKit
import Common

struct WorkspaceBackAndForthCommand: Command {
    let args = WorkspaceBackAndForthCmdArgs(rawArgs: [])

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        return prevFocusedWorkspace?.focusWorkspace() != nil
    }
}
