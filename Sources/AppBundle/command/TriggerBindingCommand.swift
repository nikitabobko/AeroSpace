import AppKit
import Common

struct TriggerBindingCommand: Command {
    let args: TriggerBindingCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        return if let mode = config.modes[args.mode] {
            if let binding = mode.bindings[args.binding.val] {
                refreshSession(forceFocus: true) { binding.commands.run(state) }
            } else {
                failCmdWithMsg(state, "Binding '\(args.binding)' is not presented in mode '\(args.mode)'")
            }
        } else {
            failCmdWithMsg(state, "Mode '\(args.mode)' doesn't exist. " +
                "Available modes: \(config.modes.keys.joined(separator: ","))")
        }
    }
}
