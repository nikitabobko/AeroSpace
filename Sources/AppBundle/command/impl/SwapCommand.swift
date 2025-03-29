import AppKit
import Common

struct SwapCommand: Command {
    let args: SwapCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io), let currentWindow = target.windowOrNil else {
            return io.err(noWindowIsFocused)
        }

        var targetWindow: Window?
        switch args.target.val {
            case .direction(let direction):
                if let (parent, ownIndex) = currentWindow.closestParent(hasChildrenInDirection: direction, withLayout: nil) {
                    targetWindow = parent.children[ownIndex + direction.focusOffset].findFocusTargetRecursive(snappedTo: direction.opposite)
                } else if args.wrapAround {
                    targetWindow = target.workspace.findFocusTargetRecursive(snappedTo: direction.opposite)
                } else {
                    return false
                }
            case .dfsRelative(let nextPrev):
                let windows = target.workspace.rootTilingContainer.allLeafWindowsRecursive
                guard let currentIndex = windows.firstIndex(where: { $0 == target.windowOrNil }) else {
                    return false
                }
                var targetIndex = switch nextPrev {
                    case .next: currentIndex + 1
                    case .prev: currentIndex - 1
                }
                if targetIndex < 0 || targetIndex >= windows.count {
                    if !args.wrapAround {
                        return false
                    }
                    targetIndex = (targetIndex + windows.count) % windows.count
                }
                targetWindow = windows[targetIndex]
        }

        guard let targetWindow else {
            return false
        }

        swapWindows(currentWindow, targetWindow)

        if args.swapFocus {
            return targetWindow.focusWindow()
        }
        return currentWindow.focusWindow()
    }
}
