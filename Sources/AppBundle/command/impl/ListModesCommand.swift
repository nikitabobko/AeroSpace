import AppKit
import Common

struct ListModesCommand: Command {
    let args: ListModesCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        if args.current {
            return io.out(activeMode ?? mainModeId)
        } else if args.json {
            let modeNames: [String] = config.modes.map { $0.key }
            return switch JSONEncoder.aeroSpaceDefault.encodeToString(modeNames).map(Result.success)
                ?? .failure("Can't encode '\(modeNames)' to JSON")
            {
                case .success(let json): io.out(json)
                case .failure(let msg): io.err(msg)
            }
        } else {
            let modeNames: [String] = config.modes.map { $0.key }
            return io.out(modeNames)
        }
    }
}
