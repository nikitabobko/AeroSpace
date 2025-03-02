import AppKit
import Common

struct TriggerBindingCommand: Command {
    let args: TriggerBindingCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        return if let mode = config.modes[args.mode] {
            if let binding = mode.bindings.values.first(where: { $0.descriptionWithKeyNotation == args.binding.val }) {
                // refreshSession is not needed since commands are already run in refreshSession
                binding.commands.runCmdSeq(env, io)
            } else {
                io.err("Binding '\(args.binding.val)' is not presented in mode '\(args.mode)'")
            }
        } else {
            io.err("Mode '\(args.mode)' doesn't exist. " +
                "Available modes: \(config.modes.keys.joined(separator: ","))")
        }
    }
}
