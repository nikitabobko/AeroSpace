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
            "--focused": trueBoolFlag(\.focused),
            "--all": trueBoolFlag(\.all),

            "--visible": boolFlag(\.filteringOptions.visible),
            "--empty": boolFlag(\.filteringOptions.empty),
            "--monitor": ArgParser(\.filteringOptions.onMonitors, parseMonitorIds),

            "--format": ArgParser(\.format, parseFormat),
            "--count": trueBoolFlag(\.outputOnlyCount),
        ],
        arguments: [],
        conflictingOptions: [
            ["--all", "--focused", "--monitor"],
            ["--format", "--count"],
        ]
    )

    fileprivate var all: Bool = false // Alias
    fileprivate var focused: Bool = false // Alias

    public var windowId: UInt32?              // unused
    public var workspaceName: WorkspaceName?  // unused
    public var filteringOptions = FilteringOptions()
    public var format: [StringInterToken] = [.value("workspace")]
    public var outputOnlyCount: Bool = false

    public struct FilteringOptions: Copyable, Equatable {
        public var onMonitors: [MonitorId] = []
        public var visible: Bool?
        public var empty: Bool?
    }
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
        .map { raw in
            raw.focused ? raw.copy(\.filteringOptions.onMonitors, [.focused]).copy(\.focused, false) : raw
        }
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
