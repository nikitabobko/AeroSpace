import AppKit
import Common
import Foundation

struct BalanceSizesCommand: Command {
    let args: BalanceSizesCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        if target.workspace.rootTilingContainer.layout == .scrolling {
            return .fail(io.err("balance-sizes command doesn't support the scrolling layout"))
        }
        balance(target.workspace.rootTilingContainer)
        return .succ
    }
}

@MainActor
private func balance(_ parent: TilingContainer) {
    for child in parent.children {
        switch parent.layout {
            case .tiles: child.setWeight(parent.orientation, 1)
            case .accordion: break // Do nothing
            case .scrolling: break
            case .tabs: break
        }
        if let child = child as? TilingContainer {
            balance(child)
        }
    }
}
