import AppKit
import Common

struct MoveWindowCommand: Command {
    let args: MoveWindowCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let target: LiveFocus
        
        if args.focused {
            // Use the currently focused window
            target = focus
        } else if let windowId = args.windowId {
            // Use the specified window ID
            guard let window = Window.get(byId: windowId) else {
                return io.err("Window with ID \(windowId) not found")
            }
            target = window.toLiveFocusOrNil() ?? focus
        } else {
            // Use the target from command context
            guard let resolvedTarget = args.resolveTargetOrReportError(env, io) else { return false }
            target = resolvedTarget
        }
        
        guard let window = target.windowOrNil else {
            return io.err("No window is focused")
        }

        // Get the current workspace and monitor
        let workspace = target.workspace
        let monitor = workspace.workspaceMonitor
        
        // Get the monitor's visible rect (with padding)
        let monitorRect = monitor.visibleRectPaddedByOuterGaps
        
        // Get the current window size
        guard let windowSize = try await window.getAxSize() else {
            return io.err("Failed to get window size")
        }
        
        // Calculate the center position for the window
        let centerX = monitorRect.topLeftX + (monitorRect.width - windowSize.width) / 2
        let centerY = monitorRect.topLeftY + (monitorRect.height - windowSize.height) / 2
        
        // Ensure the window doesn't go outside the monitor bounds
        let clampedX = max(monitorRect.topLeftX, min(centerX, monitorRect.topLeftX + monitorRect.width - windowSize.width))
        let clampedY = max(monitorRect.topLeftY, min(centerY, monitorRect.topLeftY + monitorRect.height - windowSize.height))
        
        let newPosition = CGPoint(x: clampedX, y: clampedY)
        
        // Move the window to the center
        window.setAxFrame(newPosition, windowSize)
        
        return true
    }
}
