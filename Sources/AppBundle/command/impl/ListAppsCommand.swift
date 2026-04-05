import AppKit
import Common

struct ListAppsCommand: Command {
    let args: ListAppsCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        var result = Array(MacApp.allAppsMap.values)
        if let hidden = args.macosHidden {
            result = result.filter { $0.nsApp.isHidden == hidden }
        }

        lazy var list = result.map(AeroObj.app)
        return switch true {
            case args.outputOnlyCount:
                io.out("\(result.count)")
            case args.json:
                switch list.formatToJson(args.format, ignoreRightPaddingVar: args._format.isEmpty) {
                    case .success(let json): io.out(json)
                    case .failure(let msg): io.err(msg)
                }
            default:
                switch list.format(args.format) {
                    case .success(let lines): io.out(lines)
                    case .failure(let msg): io.err(msg)
                }
        }
    }
}
