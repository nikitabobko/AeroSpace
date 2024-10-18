import OrderedCollections

let onitor = "<monitor>"
let _monitors = "\(onitor)..."

public struct ListWorkspacesCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listWorkspaces,
        allowInConfig: false,
        help: list_workspaces_help_generated,
        options: [
            // Aliases
            "--focused": trueBoolFlag(\.focused),
            "--all": trueBoolFlag(\.all),

            // Filtering flags
            "--visible": boolFlag(\.filteringOptions.visible),
            "--empty": boolFlag(\.filteringOptions.empty),
            "--monitor": ArgParser(\.filteringOptions.onMonitors, parseMonitorIds),

            // Formatting flags
            "--format": ArgParser(\._format, parseFormat),
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--json": trueBoolFlag(\.json),
        ],
        arguments: [],
        conflictingOptions: [
            ["--all", "--focused", "--monitor"],
            ["--format", "--count"],
            ["--json", "--count"],
        ]
    )

    fileprivate var all: Bool = false // Alias
    fileprivate var focused: Bool = false // Alias

    public var windowId: UInt32?              // unused
    public var workspaceName: WorkspaceName?  // unused
    public var filteringOptions = FilteringOptions()
    public var _format: [StringInterToken] = [.interVar("workspace")]
    public var outputOnlyCount: Bool = false
    public var json: Bool = false

    public struct FilteringOptions: Copyable, Equatable {
        public var onMonitors: [MonitorId] = []
        public var visible: Bool?
        public var empty: Bool?
    }
}

public extension ListWorkspacesCmdArgs {
    var format: [StringInterToken] { _format.isEmpty ? [.interVar("workspace")] : _format }
}

public func parseListWorkspacesCmdArgs(_ args: [String]) -> ParsedCmd<ListWorkspacesCmdArgs> {
    parseSpecificCmdArgs(ListWorkspacesCmdArgs(rawArgs: .init(args)), args)
        .filter("Mandatory option is not specified (--all|--focused|--monitor)") { raw in
            raw.all || raw.focused || !raw.filteringOptions.onMonitors.isEmpty
        }
        .filter("--all conflicts with any other \"filtering\" options") { raw in
            raw.all.implies(raw.filteringOptions == ListWorkspacesCmdArgs.FilteringOptions())
        }
        .filter("--focused conflicts with all other \"filtering\" options") { raw in
            raw.focused.implies(raw.filteringOptions == ListWorkspacesCmdArgs.FilteringOptions())
        }
        .map { raw in
            raw.all ? raw.copy(\.filteringOptions.onMonitors, [.all]).copy(\.all, false) : raw
        }
        .map { raw in // Expand alias
            raw.focused
                ? raw.copy(\.filteringOptions.onMonitors, [.focused])
                    .copy(\.filteringOptions.visible, true)
                    .copy(\.focused, false)
                : raw
        }
        .flatMap { if $0.json, let msg = getErrorIfFormatIsIncompatibleWithJson($0._format) { .failure(msg) } else { .cmd($0) } }
}

func parseMonitorIds(arg: String, nextArgs: inout [String]) -> Parsed<[MonitorId]> {
    let args = nextArgs.allNextNonFlagArgs()
    let possibleValues = "\(onitor) possible values: (<monitor-id>|focused|mouse|all)"
    if args.isEmpty {
        return .failure("\(_monitors) is mandatory. \(possibleValues)")
    }
    var monitors: [MonitorId] = []
    for monitor: String in args {
        if let unwrapped = Int(monitor) {
            monitors.append(.index(unwrapped - 1))
        } else if monitor == "mouse" {
            monitors.append(.mouse)
        } else if monitor == "all" {
            monitors.append(.all)
        } else if monitor == "focused" {
            monitors.append(.focused)
        } else {
            return .failure("Can't parse monitor ID '\(monitor)'. \(possibleValues)")
        }
    }
    return .success(monitors)
}

public enum MonitorId: Equatable {
    case focused
    case all
    case mouse
    case index(Int)
}
