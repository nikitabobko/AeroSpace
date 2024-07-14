import AppKit
import Common
import Foundation

struct BalanceSizesCommand: Command {
    let args: BalanceSizesCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        guard let focus = args.resolveFocusOrReportError(env, io) else { return false }
        balance(focus.workspace.rootTilingContainer)
        return true
    }
}

private func balance(_ parent: TilingContainer) {
    for child in parent.children {
        switch parent.layout {
            case .tiles: child.setWeight(parent.orientation, 1)
            case .accordion: break // Do nothing
        }
        if let child = child as? TilingContainer {
            balance(child)
        }
    }
}
