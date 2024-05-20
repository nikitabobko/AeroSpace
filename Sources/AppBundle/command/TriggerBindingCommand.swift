import AppKit
import Common

struct TriggerBindingCommand: Command {
    let args: TriggerBindingCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        return if let mode = config.modes[args.mode] {
            if let binding = mode.bindings[args.binding.val] {
                // refreshSession is not needed since commands are already run in refreshSession
                binding.commands.run(state)
            } else {
                state.failCmd(msg: "Binding '\(args.binding.val)' is not presented in mode '\(args.mode)'")
            }
        } else {
            state.failCmd(msg: "Mode '\(args.mode)' doesn't exist. " +
                "Available modes: \(config.modes.keys.joined(separator: ","))")
        }
    }
}
