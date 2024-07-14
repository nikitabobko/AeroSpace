import AppKit
import Common

struct ListWindowsCommand: Command {
    let args: ListWindowsCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        var windows: [Window] = []
        if args.focused {
            guard let focus = args.resolveFocusOrReportError(env, io) else { return false }
            if let window = focus.windowOrNil {
                windows = [window]
            } else {
                return io.err(noWindowIsFocused)
            }
        } else {
            var workspaces: Set<Workspace> = args.workspaces.isEmpty ? Workspace.all.toSet() : args.workspaces
                .flatMap { filter in
                    switch filter {
                        case .focused: [focus.workspace]
                        case .visible: Workspace.all.filter(\.isVisible)
                        case .name(let name): [Workspace.get(byName: name.raw)]
                    }
                }
                .toSet()
            if !args.monitors.isEmpty {
                let monitors: Set<CGPoint> = args.monitors.resolveMonitors(io)
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

        return switch windows.map({ AeroObj.window($0) }).format(args.format) {
            case .success(let lines): io.out(lines)
            case .failure(let msg): io.err(msg)
        }
    }
}
