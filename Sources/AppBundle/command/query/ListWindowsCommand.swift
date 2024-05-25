import AppKit
import Common

struct ListWindowsCommand: Command {
    let args: ListWindowsCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        var windows: [Window] = []
        if args.focused {
            if let window = state.subject.windowOrNil {
                windows = [window]
            } else {
                return state.failCmd(msg: "No window is focused")
            }
        } else {
            var workspaces: Set<Workspace> = args.workspaces.isEmpty ? Workspace.all.toSet() : args.workspaces
                .flatMap { filter in
                    return switch filter {
                        case .focused: [Workspace.focused]
                        case .visible: Workspace.all.filter { $0.isVisible }
                        case .name(let name): [Workspace.get(byName: name.raw)]
                    }
                }
                .toSet()
            if !args.monitors.isEmpty {
                let monitors: Set<CGPoint> = args.monitors.resolveMonitors(state)
                if monitors.isEmpty { return false }
                workspaces = workspaces.filter { monitors.contains($0.workspaceMonitor.rect.topLeftCorner) }
            }
            windows = workspaces.flatMap(\.allLeafWindowsRecursive)
            if let pid = args.pidFilter {
                windows = windows.filter { $0.app.pid == pid }
            }
            if let appId = args.appIdFilter {
                windows = windows.filter { $0.app.id == appId }
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
