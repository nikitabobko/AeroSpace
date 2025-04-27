import AppKit
import Common

@MainActor
func setupMouseTracking() {
    print("✅ Mouse tracking initialized")
    NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
        Task { @MainActor in
            guard config.mouseWindowFocus else { return }
            await autoFocusWindowUnderMouse()
        }
    }
}

@MainActor
func autoFocusWindowUnderMouse() async {
    let point = NSEvent.mouseLocation
    let workspace = point.monitorApproximation.activeWorkspace
    _ = workspace.workspaceMonitor.setActiveWorkspace(workspace)

    guard let windowUnderMouse = point.findIn(tree: workspace.rootTilingContainer, virtual: false)
    else {
        return
    }

    do {
        let focusedWindow = try await getNativeFocusedWindow()
        if focusedWindow == windowUnderMouse {
            return
        }
        windowUnderMouse.nativeFocus()
    } catch {
    }
}
