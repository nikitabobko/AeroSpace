import AppKit
import Common

struct JoinWithCommand: Command {
    let args: JoinWithCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        let direction = args.direction.val
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let currentWindow = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        guard let (parent, ownIndex) = currentWindow.closestParent(hasChildrenInDirection: direction, withLayout: nil) else {
            return .fail(io.err("No windows in the specified direction"))
        }
        switch parent.children[ownIndex + direction.focusOffset].tilingTreeNodeCasesOrDie() {
            case .tilingContainer(let joinWithTarget): // Behave similar to `move` command
                return deepMoveIn(window: currentWindow, into: joinWithTarget, moveDirection: direction, io)
            case .window(let joinWithTarget):
                let prevBinding = joinWithTarget.unbindFromParent()
                let newParent = TilingContainer(
                    parent: parent,
                    adaptiveWeight: prevBinding.adaptiveWeight,
                    parent.orientation.opposite,
                    .tiles,
                    index: prevBinding.index,
                )
                currentWindow.unbindFromParent()

                joinWithTarget.bind(to: newParent, adaptiveWeight: WEIGHT_AUTO, index: 0)
                currentWindow.bind(to: newParent, adaptiveWeight: WEIGHT_AUTO, index: direction.isPositive ? 0 : INDEX_BIND_LAST)
                return .succ
        }
    }
}
