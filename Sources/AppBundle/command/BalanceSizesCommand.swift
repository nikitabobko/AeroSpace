import AppKit
import Common
import Foundation

struct BalanceSizesCommand: Command {
    let args: BalanceSizesCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        balance(state.subject.workspace.rootTilingContainer)
        return true
    }

    func balance(_ parent: TilingContainer) {
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

}
