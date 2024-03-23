import AppKit
import Common

struct ModeCommand: Command {
    let args: ModeCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        activateMode(args.targetMode.val)
        return true
    }
}
