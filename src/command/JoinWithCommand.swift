import Common

struct JoinWithCommand: Command {
    let info: CmdStaticInfo = JoinWithCmdArgs.info
    let args: JoinWithCmdArgs

    func _run(_ subject: inout CommandSubject, _ stdout: inout [String]) -> Bool {
        check(Thread.current.isMainThread)
        let direction = args.direction
        guard let currentWindow = subject.windowOrNil else {
            stdout.append(noWindowIsFocused)
            return false
        }
        guard let (parent, ownIndex) = currentWindow.closestParent(hasChildrenInDirection: direction, withLayout: nil) else {
            stdout.append("No windows in specified direction")
            return false
        }
        let moveInTarget = parent.children[ownIndex + direction.focusOffset]
        let prevBinding = moveInTarget.unbindFromParent()
        let newParent = TilingContainer(
            parent: parent,
            adaptiveWeight: prevBinding.adaptiveWeight,
            parent.orientation.opposite,
            .tiles,
            index: prevBinding.index
        )
        currentWindow.unbindFromParent()

        moveInTarget.bind(to: newParent, adaptiveWeight: WEIGHT_AUTO, index: 0)
        currentWindow.bind(to: newParent, adaptiveWeight: WEIGHT_AUTO, index: direction.isPositive ? 0 : INDEX_BIND_LAST)
        return true
    }
}
