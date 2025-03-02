import AppKit
import Common

struct MoveMouseCommand: Command {
    let args: MoveMouseCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let mouse = mouseLocation
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        switch args.mouseTarget.val {
            case .windowLazyCenter:
                guard let rect = windowSubjectRectOrReportError(target, io) else { return false }
                if rect.contains(mouse) {
                    io.err("The mouse already belongs to the window. Tip: use --fail-if-noop to exit with non-zero code")
                    return !args.failIfNoop
                }
                return moveMouse(io, rect.center)
            case .windowForceCenter:
                guard let rect = windowSubjectRectOrReportError(target, io) else { return false }
                return moveMouse(io, rect.center)
            case .monitorLazyCenter:
                let rect = target.workspace.workspaceMonitor.rect
                if rect.contains(mouse) {
                    io.err("The mouse already belongs to the monitor. Tip: use --fail-if-noop to exit with non-zero code")
                    return !args.failIfNoop
                }
                return moveMouse(io, rect.center)
            case .monitorForceCenter:
                return moveMouse(io, target.workspace.workspaceMonitor.rect.center)
        }
    }
}

private func moveMouse(_ io: CmdIo, _ point: CGPoint) -> Bool {
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
        return io.err("Failed to move mouse")
    }
}

@MainActor private func windowSubjectRectOrReportError(_ target: LiveFocus, _ io: CmdIo) -> Rect? {
    // todo bug it's bad that we operate on the "ax physical" state directly. command seq won't work correctly
    //      focus <direction> command has the similar problem
    if let window: Window = target.windowOrNil {
        if let rect = window.lastAppliedLayoutPhysicalRect ?? window.getRect() {
            return rect
        } else {
            io.err("Failed to get rect of window '\(window.windowId)'")
            return nil
        }
    } else {
        io.err(noWindowIsFocused)
        return nil
    }
}
