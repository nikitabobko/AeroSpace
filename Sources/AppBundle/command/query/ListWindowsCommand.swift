import AppKit
import Common

struct ListWindowsCommand: Command {
    let args: ListWindowsCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        var windows: [Window] = []
        switch args {
            case .manual(let manual):
                var workspaces: Set<Workspace> = manual.workspaces.isEmpty ? Workspace.all.toSet() : manual.workspaces
                    .flatMap { filter in
                        switch filter {
                            case .focused:
                                return [Workspace.focused]
                            case .visible:
                                return Workspace.all.filter { $0.isVisible }
                            case .name(let name):
                                return [Workspace.get(byName: name.raw)]
                        }
                    }
                    .toSet()
                if !manual.monitors.isEmpty {
                    let monitors: Set<CGPoint> = manual.monitors.resolveMonitors(state)
                    if monitors.isEmpty { return false }
                    workspaces = workspaces.filter { monitors.contains($0.workspaceMonitor.rect.topLeftCorner) }
                }
                windows = workspaces.flatMap(\.allLeafWindowsRecursive)
                if let pid = manual.pidFilter {
                    windows = windows.filter { $0.app.pid == pid }
                }
                if let macosHiddenApp = manual.macosHiddenApp {
                    windows = windows.filter { $0.macAppUnsafe.nsApp.isHidden == macosHiddenApp }
                }
                if let minimized = manual.macosMinimized {
                    windows = windows.filter { ($0.asMacWindow().axWindow.get(Ax.minimizedAttr) ?? false) == minimized }
                }
                if let fullscreen = manual.macosFullscreen {
                    windows = windows.filter { ($0.asMacWindow().axWindow.get(Ax.isFullscreenAttr) ?? false) == fullscreen }
                }
                if let appId = manual.appIdFilter {
                    windows = windows.filter { $0.app.id == appId }
                }
            case .focused:
                if let window = state.subject.windowOrNil {
                    windows = [window]
                } else {
                    state.stderr.append("No window is focused")
                    return false
                }
        }
        state.stdout += windows
            .map { window in
                [String(window.windowId), window.app.name ?? "NULL-APP-NAME", window.title]
            }
            .toPaddingTable()
        return true
    }
}
