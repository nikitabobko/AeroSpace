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
    let equalWeight: CGFloat? = switch parent.layout {
        case .tiles: CGFloat(parent.children.sumOfDouble { $0.getWeight(parent.orientation) }).div(parent.children.count)
        case .accordion: nil
    }
    for child in parent.children {
        switch parent.layout {
            case .tiles: child.setWeight(parent.orientation, equalWeight ?? 1)
            case .accordion: break // Do nothing
        }
        if let child = child as? TilingContainer {
            balance(child)
        }
    }
}
