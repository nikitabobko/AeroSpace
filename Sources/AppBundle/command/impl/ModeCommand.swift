import AppKit
import Common

struct ModeCommand: Command {
    let args: ModeCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        activateMode(args.targetMode.val)
        return true
    }
}
