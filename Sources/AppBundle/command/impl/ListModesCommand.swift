import AppKit
import Common

struct ListModesCommand: Command {
    let args: ListModesCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let modes: [String] = args.current ? [activeMode ?? mainModeId] : config.modes.keys.sorted()
        return switch true {
            case args.outputOnlyCount:
                io.out("\(modes.count)")
            case args.json:
                JSONEncoder.aeroSpaceDefault.encodeToString(modes.map { ["mode-id": $0] }).map(io.out)
                    ?? io.err("Failed to encode JSON")
            default:
                io.out(modes)
        }
    }
}
