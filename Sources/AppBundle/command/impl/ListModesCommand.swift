import AppKit
import Common

struct ListModesCommand: Command {
    let args: ListModesCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        if args.current {
            return io.out(activeMode ?? mainModeId)
        } else {
            let modeNames: [String] = config.modes.map { $0.key }
            return io.out(modeNames)
        }
    }
}
