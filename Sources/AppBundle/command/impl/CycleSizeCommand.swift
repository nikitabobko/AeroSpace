import AppKit
import Common

struct CycleSizeCommand: Command {
    let args: CycleSizeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let resizeTarget = resolveResizeTarget(target.windowOrNil, args.axis) else {
            return .fail(io.err("cycle-size command doesn't support floating windows yet https://github.com/nikitabobko/AeroSpace/issues/9"))
        }
        let parentWeight = resizeTarget.parentWeight
        guard parentWeight > 0 else { return .fail }

        let sizes = args.sizes.val
        let currentSize = (resizeTarget.nodeWeight / parentWeight * 100).rounded()
        // If the current size isn't one of the requested sizes then start the cycle from the beginning
        let nextIndex = sizes.firstIndex { CGFloat($0) == currentSize }.map { ($0 + 1) % sizes.count } ?? 0

        let diff = CGFloat(sizes[nextIndex]) * parentWeight / 100 - resizeTarget.nodeWeight
        return resizeTarget.changeWeight(by: diff) ? .succ : .fail
    }
}
