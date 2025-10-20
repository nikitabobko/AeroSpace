import AppKit
import Common

struct ListWindowsCommand: Command {
    let args: ListWindowsCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let focus = focus
        var windows: [Window] = []

        if args.filteringOptions.focused {
            if let window = focus.windowOrNil {
                windows = [window]
            } else {
                return io.err(noWindowIsFocused)
            }
        } else {
            var workspaces: Set<Workspace> = args.filteringOptions.workspaces.isEmpty
                ? Workspace.all.toSet()
                : args.filteringOptions.workspaces
                    .flatMap { filter in
                        switch filter {
                            case .focused: [focus.workspace]
                            case .visible: Workspace.all.filter(\.isVisible)
                            case .name(let name): [Workspace.get(byName: name.raw)]
                        }
                    }
                    .toSet()
            if !args.filteringOptions.monitors.isEmpty {
                let monitors: Set<CGPoint> = args.filteringOptions.monitors.resolveMonitors(io)
                if monitors.isEmpty { return false }
                workspaces = workspaces.filter { monitors.contains($0.workspaceMonitor.rect.topLeftCorner) }
            }
            windows = workspaces.flatMap(\.allLeafWindowsRecursive)
            if let pid = args.filteringOptions.pidFilter {
                windows = windows.filter { $0.app.pid == pid }
            }
            if let appId = args.filteringOptions.appIdFilter {
                windows = windows.filter { $0.app.rawAppBundleId == appId }
            }
        }

        if args.outputOnlyCount {
            return io.out("\(windows.count)")
        } else {
            var _list: [(window: Window, title: String)] = [] // todo cleanup
            for window in windows {
                _list.append((window, try await window.title))
            }
            _list = _list.filter { $0.window.isBound }
            _list = _list.sortedBy([{ $0.window.app.name ?? "" }, \.title])

            let list = _list.map { AeroObj.window(window: $0.window, title: $0.title) }
            if args.json {
                return switch list.formatToJson(args.format, ignoreRightPaddingVar: args._format.isEmpty) {
                    case .success(let json): io.out(json)
                    case .failure(let msg): io.err(msg)
                }
            } else {
                return switch list.format(args.format) {
                    case .success(let lines): io.out(lines)
                    case .failure(let msg): io.err(msg)
                }
            }
        }
    }
}
