import AppKit
import Common
import Foundation

struct SetGapsCommand: Command {
    let args: SetGapsCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        if args.useStdin {
            return runBatch(io)
        }
        return runSingle(args.workspaceName?.raw, io)
    }

    /// Single workspace: `set-gaps [--workspace ws] --outer-left-right N --outer-top-bottom N --inner N`
    @MainActor private func runSingle(_ wsName: String?, _ io: CmdIo) -> Bool {
        let currentGaps: Gaps
        if let wsName {
            currentGaps = config.workspaceGaps[wsName] ?? config.gaps
        } else {
            currentGaps = config.gaps
        }

        var newGaps = currentGaps
        if let lr = args.outerLeftRight {
            let v = Int(lr)
            newGaps.outer = Gaps.Outer(
                left: .constant(v), bottom: newGaps.outer.bottom,
                top: newGaps.outer.top, right: .constant(v)
            )
        }
        if let tb = args.outerTopBottom {
            let v = Int(tb)
            newGaps.outer = Gaps.Outer(
                left: newGaps.outer.left, bottom: .constant(v),
                top: .constant(v), right: newGaps.outer.right
            )
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

    /// Batch: `set-gaps --stdin` with JSON on stdin
    /// Format: {"workspace": {"inner": N, "outerLeftRight": N, "outerTopBottom": N}, ...}
    @MainActor private func runBatch(_ io: CmdIo) -> Bool {
        let raw = io.readStdin()
        guard let data = raw.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Int]] else {
            return io.err("Invalid JSON on stdin. Expected: {\"workspace\": {\"inner\": N, \"outerLeftRight\": N, \"outerTopBottom\": N}, ...}")
        }

        for (wsName, gaps) in dict {
            let currentGaps = config.workspaceGaps[wsName] ?? config.gaps
            var newGaps = currentGaps
            if let lr = gaps["outerLeftRight"] {
                newGaps.outer = Gaps.Outer(
                    left: .constant(lr), bottom: newGaps.outer.bottom,
                    top: newGaps.outer.top, right: .constant(lr)
                )
            }
            if let tb = gaps["outerTopBottom"] {
                newGaps.outer = Gaps.Outer(
                    left: newGaps.outer.left, bottom: .constant(tb),
                    top: .constant(tb), right: newGaps.outer.right
                )
            }
            if let inner = gaps["inner"] {
                newGaps.inner = Gaps.Inner(vertical: inner, horizontal: inner)
            }
            config.workspaceGaps[wsName] = newGaps
        }
        return true
    }
}
