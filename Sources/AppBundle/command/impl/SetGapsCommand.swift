import AppKit
import Common

struct SetGapsCommand: Command {
    let args: SetGapsCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let wsName = args.workspaceName?.raw

        let currentGaps: Gaps
        if let wsName {
            currentGaps = config.workspaceGaps[wsName] ?? config.gaps
        } else {
            currentGaps = config.gaps
        }

        var newGaps = currentGaps
        if let outer = args.outer {
            let v = Int(outer)
            newGaps.outer = Gaps.Outer(left: v, bottom: v, top: v, right: v)
        }
        if let inner = args.inner {
            let v = Int(inner)
            newGaps.inner = Gaps.Inner(vertical: v, horizontal: v)
        }

        if let wsName {
            config.workspaceGaps[wsName] = newGaps
        } else {
            config.gaps = newGaps
        }

        return true
    }
}
