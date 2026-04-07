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

    /// Single workspace: `set-gaps [--workspace ws] --outer N --inner N`
    @MainActor private func runSingle(_ wsName: String?, _ io: CmdIo) -> Bool {
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

    /// Batch: `set-gaps --stdin` with JSON on stdin
    /// Format: {"workspace": {"inner": N, "outer": N}, ...}
    @MainActor private func runBatch(_ io: CmdIo) -> Bool {
        let raw = io.readStdin()
        guard let data = raw.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Int]] else {
            return io.err("Invalid JSON on stdin. Expected: {\"workspace\": {\"inner\": N, \"outer\": N}, ...}")
        }

        for (wsName, gaps) in dict {
            let inner = gaps["inner"]
            let outer = gaps["outer"]
            let currentGaps = config.workspaceGaps[wsName] ?? config.gaps
            var newGaps = currentGaps
            if let outer {
                newGaps.outer = Gaps.Outer(left: outer, bottom: outer, top: outer, right: outer)
            }
            if let inner {
                newGaps.inner = Gaps.Inner(vertical: inner, horizontal: inner)
            }
            config.workspaceGaps[wsName] = newGaps
        }
        return true
    }
}
