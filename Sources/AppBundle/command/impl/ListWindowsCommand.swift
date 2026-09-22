import AppKit
import Common

struct ListWindowsCommand: Command {
    let args: ListWindowsCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        let focus = focus
        var windows: [Window] = []

        if args.filteringOptions.focused {
            switch focus.windowOrNil {
                case let window?: windows = [window]
                case nil: return .fail(io.err(noWindowIsFocused))
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
                if monitors.isEmpty { return .fail }
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
            return .succ(io.out("\(windows.count)"))
        } else {
            let dfsRanks: [UInt32: Int] = args.sortBy.contains(.dfs) ? await buildDfsRanks(of: windows) : [:]
            var _list: [WindowWithPrefetchedTitle] = [] // todo cleanup
            for window in windows {
                guard let window = try? await WindowWithPrefetchedTitle.resolveWindow(window, for: args.format, alsoNeedsTitle: args.sortBy.contains(.windowTitle), .nonCancellable) else { return .fail(io.err(bugPrompt())) }
                _list.append(window)
            }
            _list = _list.filter { $0.window.isBound }
            let sortByWithFallback = args.sortBy + [.appName, .windowTitle, .windowId]
            func compare<T: Comparable>(_ lhs: T, _ rhs: T) -> Bool? { lhs != rhs ? lhs < rhs : nil }
            _list = _list.sortedBy(sortByWithFallback.map { sortBy in
                switch sortBy {
                    case .dfs: { compare(dfsRanks[$0.window.windowId] ?? .max, dfsRanks[$1.window.windowId] ?? .max) }
                    case .appName: { compare($0.window.app.name ?? "", $1.window.app.name ?? "") }
                    case .windowTitle: { compare($0.title ?? "", $1.title ?? "") }
                    case .windowId: { compare($0.window.windowId, $1.window.windowId) }
                }
            })

            let list = _list.map { AeroObj.window($0) }
            if args.json {
                return switch list.formatToJson(args.format, ignoreRightPaddingVar: args._format.isEmpty) {
                    case .success(let json): .succ(io.out(json))
                    case .failure(let msg): .fail(io.err(msg))
                }
            } else {
                return switch list.format(args.format) {
                    case .success(let lines): .succ(io.out(lines))
                    case .failure(let msg): .fail(io.err(msg.map(\.description).joinErrors()))
                }
            }
        }
    }
}

@MainActor
private func buildDfsRanks(of windows: [Window]) async -> [UInt32: Int] {
    let relevant: Set<Workspace> = windows.compactMap(\.nodeWorkspace).toSet()
    let workspaces = Workspace.all.filter(relevant.contains).withIndex
        .map { (index: $0.index, workspace: $0.value, monitorId: $0.value.workspaceMonitor.monitorId_oneBased ?? .max) }
        .sortedBy([{ $0.monitorId }, { $0.index }])
        .map(\.workspace)

    var ranks: [UInt32: Int] = [:]
    for workspace in workspaces {
        for window in await workspace.dfsWindowsWithFloatingAsTiling() {
            ranks[window.windowId] = ranks.count
        }
    }
    return ranks
}

extension Workspace {
    @MainActor fileprivate func dfsWindowsWithFloatingAsTiling() async -> [Window] {
        var overrides: [ObjectIdentifier: [TreeNode]] = [:]
        for placement in await floatingWindowPlacements(workspace: self) {
            var siblings = overrides[ObjectIdentifier(placement.tilingParent)] ?? placement.tilingParent.children
            siblings.insert(placement.window, at: placement.index)
            overrides[ObjectIdentifier(placement.tilingParent)] = siblings
        }
        return rootTilingContainer.allLeafWindowsRecursive { overrides[ObjectIdentifier($0)] ?? $0.children }
    }
}
