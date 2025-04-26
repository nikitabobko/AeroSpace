import AppKit
import Common

@MainActor
var autoFocusEnabled: Bool = true

@MainActor
func setupMouseTracking() {
    print("✅ Mouse tracking initialized")
    NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
        Task { @MainActor in
            guard autoFocusEnabled else { return }
            await autoFocusWindowUnderMouse()
        }
    }
}

@MainActor
func autoFocusWindowUnderMouse() async {
    let point = NSEvent.mouseLocation

    let workspace = point.monitorApproximation.activeWorkspace

    let didSet = workspace.workspaceMonitor.setActiveWorkspace(workspace)
    if didSet {
        print("🌟 Set active workspace to: \(workspace.name)")
    } else {
        print("⚠️ Failed to set active workspace for workspace: \(workspace.name)")
    }

    guard let windowUnderMouse = point.findIn(tree: workspace.rootTilingContainer, virtual: false)
    else {
        print("🖱 No window found under mouse at point \(point)")
        return
    }
    print("✅ Found window under mouse: windowId=\(windowUnderMouse.windowId)")

    let args = FocusCmdArgs.init(rawArgs: [], windowId: windowUnderMouse.windowId)
    let cmd = FocusCommand(
        args: args)
    do {
        try await cmd.run(.defaultEnv, .emptyStdin)
        print("🎯 Focused window: \(windowUnderMouse.windowId)")
    } catch {
        print("❌ Failed to focus window: \(windowUnderMouse.windowId) with error: \(error)")
    }
}
