import AppKit
import Common

struct MoveMouseCommand: Command {
    let args: MoveMouseCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        let mouse = mouseLocation
        switch args.mouseTarget.val {
            case .windowLazyCenter:
                guard let rect = windowSubjectRect(state) else { return false }
                if rect.contains(mouse) {
                    state.stderr.append("The mouse already belongs to the window. Tip: use --fail-if-noop to exit with non-zero code")
                    return !args.failIfNoop
                }
                return moveMouse(state, rect.center)
            case .windowForceCenter:
                guard let rect = windowSubjectRect(state) else { return false }
                return moveMouse(state, rect.center)
            case .monitorLazyCenter:
                let rect = state.subject.workspace.workspaceMonitor.rect
                if rect.contains(mouse) {
                    state.stderr.append("The mouse already belongs to the monitor. Tip: use --fail-if-noop to exit with non-zero code")
                    return !args.failIfNoop
                }
                return moveMouse(state, rect.center)
            case .monitorForceCenter:
                return moveMouse(state, state.subject.workspace.workspaceMonitor.rect.center)
        }
    }
}

private func moveMouse(_ state: CommandMutableState, _ point: CGPoint) -> Bool {
    let event = CGEvent(
        mouseEventSource: nil,
        mouseType: CGEventType.mouseMoved,
        mouseCursorPosition: point,
        mouseButton: CGMouseButton.left
    )
    if let event {
        event.post(tap: CGEventTapLocation.cghidEventTap)
        return true
    } else {
        return state.failCmd(msg: "Failed to move mouse")
    }
}

private func windowSubjectRect(_ state: CommandMutableState) -> Rect? {
    // todo bug it's bad that we operate on the "ax physical" state directly. command seq won't work correctly
    //      focus <direction> command has the similar problem
    if let window: Window = state.subject.windowOrNil {
        if let rect = window.lastAppliedLayoutPhysicalRect ?? window.getRect() {
            return rect
        } else {
            state.stderr.append("Failed to get rect of window '\(window.windowId)'")
            return nil
        }
    } else {
        state.stderr.append(noWindowIsFocused)
        return nil
    }
}
