import AppKit
import Common

struct ModeCommand: Command {
    let args: ModeCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        activateMode(args.targetMode.val)
        return true
    }
}
