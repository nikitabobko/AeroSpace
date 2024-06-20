import AppKit
import Common
import Foundation

struct BalanceSizesCommand: Command {
    let args = BalanceSizesCmdArgs(rawArgs: [])

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        balance(state.subject.workspace.rootTilingContainer)
        return true
    }

    func balance(_ parent: TilingContainer) {
        parent.children.forEach { child in
            if parent.layout == .tiles {
                child.setWeight(parent.orientation, 1)
            }
            if let child = child as? TilingContainer {
                balance(child)
            }
        }
    }

}
