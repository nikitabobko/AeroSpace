import AppKit
import Common

struct JoinWithCommand: Command {
    let args: JoinWithCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        let direction = args.direction.val
        guard let currentWindow = state.subject.windowOrNil else {
            return state.failCmd(msg: noWindowIsFocused)
        }
        guard let (parent, ownIndex) = currentWindow.closestParent(hasChildrenInDirection: direction, withLayout: nil) else {
            return state.failCmd(msg: "No windows in specified direction")
        }
        let joinWithTarget = parent.children[ownIndex + direction.focusOffset]
        let prevBinding = joinWithTarget.unbindFromParent()
        let newParent = TilingContainer(
            parent: parent,
            adaptiveWeight: prevBinding.adaptiveWeight,
            parent.orientation.opposite,
            .tiles,
            index: prevBinding.index
        )
        currentWindow.unbindFromParent()

        joinWithTarget.bind(to: newParent, adaptiveWeight: WEIGHT_AUTO, index: 0)
        currentWindow.bind(to: newParent, adaptiveWeight: WEIGHT_AUTO, index: direction.isPositive ? 0 : INDEX_BIND_LAST)
        return true
    }
}
