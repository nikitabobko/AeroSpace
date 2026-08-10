import AppKit
import Common
import Foundation

struct BalanceSizesCommand: Command {
    let args: BalanceSizesCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        balance(target.workspace.rootTilingContainer)
        return .succ
    }
}

@MainActor
private func balance(_ parent: TilingContainer) {
    switch parent.layout {
        case .tiles:
            // Redistribute the weights that the container already has, instead of assigning an arbitrary constant.
            // Weights are only converted to real sizes by the layout pass, which happens once after the whole list of
            // commands of a binding has run. Preserving the total keeps the weights meaningful for commands that run
            // later in the same list (e.g. `resize`) https://github.com/nikitabobko/AeroSpace/issues/1837
            let total = CGFloat(parent.children.sumOfDouble { $0.getWeight(parent.orientation) })
            if let equalWeight = total.div(parent.children.count) {
                for child in parent.children {
                    child.setWeight(parent.orientation, equalWeight)
                }
            }
        case .accordion: break // Do nothing
    }
    for child in parent.children {
        if let child = child as? TilingContainer {
            balance(child)
        }
    }
}
