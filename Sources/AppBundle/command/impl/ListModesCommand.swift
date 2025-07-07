import AppKit
import Common

struct ListModesCommand: Command {
    let args: ListModesCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        if args.outputOnlyCount {
            let count = args.current ? 1 : config.modes.count
            return io.out("\(count)")
        }

        if args.json {
            let modeNames = args.current ? [activeMode ?? mainModeId] : config.modes.keys.sorted()
            let modeData = modeNames.map { ["mode-id": $0] }
            return JSONEncoder.aeroSpaceDefault.encodeToString(modeData).map(io.out)
                ?? io.err("Failed to encode JSON")
        }

        if args.current {
            return io.out(activeMode ?? mainModeId)
        } else {
            let modeNames: [String] = config.modes.keys.sorted()
            return io.out(modeNames)
        }
    }
}
