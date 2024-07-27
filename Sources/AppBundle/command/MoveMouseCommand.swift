import AppKit
import Common

struct MoveMouseCommand: Command {
    let args: MoveMouseCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        let mouse = mouseLocation
        let point: Result<CGPoint, String> = switch args.mouseTarget.val {
            case .windowLazyCenter:
                windowSubjectRect(state)
                    .flatMap { $0.takeIf { !$0.contains(mouse) }.orFailure("The mouse already belongs to the window") }
                    .map(\.center)
            case .windowForceCenter:
                windowSubjectRect(state).map(\.center)
            case .monitorLazyCenter:
                Result.success(state.subject.workspace.workspaceMonitor.rect)
                    .flatMap { $0.takeIf { !$0.contains(mouse) }.orFailure("The mouse already belongs to the monitor") }
                    .map(\.center)
            case .monitorForceCenter:
                .success(state.subject.workspace.workspaceMonitor.rect.center)
        }
        switch point {
            case .success(let point):
                CGEvent(
                    mouseEventSource: nil,
                    mouseType: CGEventType.mouseMoved,
                    mouseCursorPosition: point,
                    mouseButton: CGMouseButton.left
                )?.post(tap: CGEventTapLocation.cghidEventTap)
                return true
            case .failure(let msg):
                return state.failCmd(msg: msg)
        }
    }
}

private func windowSubjectRect(_ state: CommandMutableState) -> Result<Rect, String> {
    // todo bug it's bad that we operate on the "ax physical" state directly. command seq won't work correctly
    //      focus <direction> command has the similar problem
    if let window: Window = state.subject.windowOrNil {
        if let rect = window.lastAppliedLayoutPhysicalRect ?? window.getRect() {
            return .success(rect)
        } else {
            return .failure("Failed to get rect of window '\(window.windowId)'")
        }
    } else {
        return .failure(noWindowIsFocused)
    }
}
