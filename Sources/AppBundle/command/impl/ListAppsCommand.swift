import AppKit
import Common

struct ListAppsCommand: Command {
    let args: ListAppsCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        var result = apps
        if let hidden = args.macosHidden {
            result = result.filter { $0.asMacApp().nsApp.isHidden == hidden }
        }

        if args.outputOnlyCount {
            return io.out("\(result.count)")
        } else {
            return switch result.map({ AeroObj.app($0) }).format(args.format) {
                case .success(let lines): io.out(lines)
                case .failure(let msg): io.err(msg)
            }
        }
    }
}
