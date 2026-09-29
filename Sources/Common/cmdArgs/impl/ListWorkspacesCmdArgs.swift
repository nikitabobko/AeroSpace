import OrderedCollections

let onitor = "<monitor>"
let _monitors = "\(onitor)..."

public struct ListWorkspacesCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public static let parser: CmdParser<Self> = .init(
        kind: .listWorkspaces,
        help: list_workspaces_help_generated,
        flags: [
            // Aliases
            "--focused": trueBoolFlag(\.focused),
            "--all": trueBoolFlag(\.all),

            // Filtering flags
            "--visible": boolFlag(\.filteringFlags.visible),
            "--empty": boolFlag(\.filteringFlags.empty),
            "--monitor": ArgParser(\.filteringFlags.onMonitors, parseMonitorIds),

            // Formatting flags
            "--format": formatParser(\._format, for: .workspace),
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--json": trueBoolFlag(\.json),
        ],
        posArgs: [],
        conflictingFlags: [
            ["--all", "--focused", "--monitor"],
            ["--count", "--format"],
            ["--count", "--json"],
        ],
    )

    fileprivate var all: Bool = false // Alias
    fileprivate var focused: Bool = false // Alias

    public var filteringFlags = FilteringFlags()
    public var _format: [InterToken<InterVar>] = [.interVar(.formatVar(.workspace(.workspaceName)))]
    public var outputOnlyCount: Bool = false
    public var json: Bool = false

    public struct FilteringFlags: Withable, Equatable, Sendable {
        public var onMonitors: [MonitorId] = []
        public var visible: Bool?
        public var empty: Bool?
    }
}

extension ListWorkspacesCmdArgs {
    public var format: [InterToken<InterVar>] { _format.isEmpty ? [.interVar(.formatVar(.workspace(.workspaceName)))] : _format }
}

func parseListWorkspacesCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListWorkspacesCmdArgs> {
    parseSpecificCmdArgs(ListWorkspacesCmdArgs(commonState: .init(args)), args)
        .filter("Mandatory option is not specified (--all|--focused|--monitor)") { raw in
            raw.all || raw.focused || !raw.filteringFlags.onMonitors.isEmpty
        }
        .filter("--all conflicts with any other \"filtering\" options") { raw in
            raw.all.implies(raw.filteringFlags == ListWorkspacesCmdArgs.FilteringFlags())
        }
        .filter("--focused conflicts with all other \"filtering\" options") { raw in
            raw.focused.implies(raw.filteringFlags == ListWorkspacesCmdArgs.FilteringFlags())
        }
        .map { raw in
            raw.all ? raw.with(\.filteringFlags.onMonitors, [.all]).with(\.all, false) : raw
        }
        .map { raw in // Expand alias
            raw.focused
                ? raw.with(\.filteringFlags.onMonitors, [.focused])
                    .with(\.filteringFlags.visible, true)
                    .with(\.focused, false)
                : raw
        }
        .flatMap { if $0.json, let msg = getErrorIfFormatIsIncompatibleWithJson($0._format) { .failure(msg) } else { .cmd($0) } }
}

func parseMonitorIds(input: SubArgParserInput) -> ParsedCliArgs<[MonitorId]> {
    let args = input.nonFlagArgs()
    let possibleValues = "\(onitor) possible values: (<monitor-id>|focused|mouse|all)"
    if args.isEmpty {
        return .fail("\(_monitors) is mandatory. \(possibleValues)", advanceBy: args.count)
    }
    var monitors: [MonitorId] = []
    var i = 0
    for monitor in args {
        switch Int.init(monitor) {
            case let unwrapped?: monitors.append(.index(unwrapped - 1))
            case _ where monitor == "mouse": monitors.append(.mouse)
            case _ where monitor == "all": monitors.append(.all)
            case _ where monitor == "focused": monitors.append(.focused)
            default: return .fail("Can't parse monitor ID '\(monitor)'. \(possibleValues)", advanceBy: i + 1)
        }
        i += 1
    }
    return .succ(monitors, advanceBy: monitors.count)
}

public enum MonitorId: Equatable, Sendable {
    case focused
    case all
    case mouse
    case index(Int)
}
