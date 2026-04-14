import AppKit
import Common

struct ListModesCommand: Command {
    let args: ListModesCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        let modes: [String] = args.current ? [activeMode ?? mainModeId] : config.modes.keys.sorted()
        return switch true {
            case args.outputOnlyCount:
                .succ(io.out("\(modes.count)"))
            case args.json:
                JSONEncoder.aeroSpaceDefault.encodeToString(modes.map { ["mode-id": $0] }).map { .succ(io.out($0)) }
                    ?? .fail(io.err("Failed to encode JSON"))
            default:
                .succ(io.out(modes))
        }
    }
}
