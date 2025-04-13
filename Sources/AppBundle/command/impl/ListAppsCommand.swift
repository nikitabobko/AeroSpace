import AppKit
import Common

struct ListAppsCommand: Command {
    let args: ListAppsCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        var result = Array(MacApp.allAppsMap.values)
        if let hidden = args.macosHidden {
            result = result.filter { $0.nsApp.isHidden == hidden }
        }

        if args.outputOnlyCount {
            return io.out("\(result.count)")
        } else {
            let list = result.map { AeroObj.app($0) }
            if args.json {
                return switch try await list.formatToJson(args.format, ignoreRightPaddingVar: args._format.isEmpty) {
                    case .success(let json): io.out(json)
                    case .failure(let msg): io.err(msg)
                }
            } else {
                return switch try await list.format(args.format) {
                    case .success(let lines): io.out(lines)
                    case .failure(let msg): io.err(msg)
                }
            }
        }
    }
}
