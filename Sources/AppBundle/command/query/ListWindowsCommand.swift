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
                    switch filter {
                        case .focused: [Workspace.focused]
                        case .visible: Workspace.all.filter(\.isVisible)
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
        windows = windows.sorted(using: [SelectorComparator { $0.app.name ?? "" }, SelectorComparator(selector: \.title)])
        var table: [[String]] = []
        var padLastColumn = false // hack. right-padding should be properly expanded
        for window in windows {
            var errors: [String] = []
            var line: [String] = []
            var current: String = ""
            for (index, token) in args.format.enumerated() {
                switch token {
                    case .value("right-padding"):
                        line.append(current)
                        current = ""
                        if index == args.format.count - 1 {
                            padLastColumn = true
                        }
                    case .literal(let literal): current.append(literal)
                    case .value(let value):
                        switch value.expandTreeNodeVar(window: window) {
                            case .success(let prop): current.append(prop)
                            case .failure(let msg): errors.append(msg)
                        }
                }
            }
            if !current.isEmpty {
                line.append(current)
            }
            if errors.isEmpty {
                table.append(line)
            } else {
                return state.failCmd(msg: errors.joinErrors())
            }
        }
        state.stdout += table.toPaddingTable(columnSeparator: "", padLastColumn: padLastColumn)
        return true
    }
}

private extension String {
    func expandTreeNodeVar(window: Window) -> Result<String, String> {
        switch self {
            case "newline": .success("\n")
            case "tab": .success("\t")
            case "window-id": .success(window.windowId.description)
            case "window-title": .success(window.title)
            case "app-name": .success(window.app.name ?? "NULL-APP-NAME")
            case "app-pid": .success(window.app.pid.description)
            case "app-id": .success(window.app.id ?? "NULL-APP-ID")
            case "workspace": .success(window.workspace?.name ?? "NULL-WOKRSPACE")
            case "monitor-id": .success(window.nodeMonitor?.monitorId?.description ?? "NULL-MONITOR-ID")
            case "monitor-name": .success(window.nodeMonitor?.name ?? "NULL-MONITOR-NAME")
            default: .failure("Unknown interpolation variable '\(self)'")
        }
    }
}
