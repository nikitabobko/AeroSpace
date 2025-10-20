import OrderedCollections

let onitor = "<monitor>"
let _monitors = "\(onitor)..."

public struct ListWorkspacesCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listWorkspaces,
        allowInConfig: false,
        help: list_workspaces_help_generated,
        flags: [
            // Aliases
            "--focused": trueBoolFlag(\.focused),
            "--all": trueBoolFlag(\.all),

            // Filtering flags
            "--visible": boolFlag(\.filteringOptions.visible),
            "--empty": boolFlag(\.filteringOptions.empty),
            "--monitor": SubArgParser(\.filteringOptions.onMonitors, parseMonitorIds),

            // Formatting flags
            "--format": formatParser(\._format, for: .workspace),
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--json": trueBoolFlag(\.json),
        ],
        posArgs: [],
        conflictingOptions: [
            ["--all", "--focused", "--monitor"],
            ["--count", "--format"],
            ["--count", "--json"],
        ],
    )

    fileprivate var all: Bool = false // Alias
    fileprivate var focused: Bool = false // Alias

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
    public var filteringOptions = FilteringOptions()
    public var _format: [StringInterToken] = [.interVar("workspace")]
    public var outputOnlyCount: Bool = false
    public var json: Bool = false

    public struct FilteringOptions: ConvenienceCopyable, Equatable, Sendable {
        public var onMonitors: [MonitorId] = []
        public var visible: Bool?
        public var empty: Bool?
    }
}

extension ListWorkspacesCmdArgs {
    public var format: [StringInterToken] { _format.isEmpty ? [.interVar("workspace")] : _format }
}

public func parseListWorkspacesCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListWorkspacesCmdArgs> {
    parseSpecificCmdArgs(ListWorkspacesCmdArgs(rawArgsForStrRepr: .init(args)), args)
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
            case .some(let unwrapped):
                monitors.append(.index(unwrapped - 1))
            case _ where monitor == "mouse":
                monitors.append(.mouse)
            case _ where monitor == "all":
                monitors.append(.all)
            case _ where monitor == "focused":
                monitors.append(.focused)
            default:
                return .fail("Can't parse monitor ID '\(monitor)'. \(possibleValues)", advanceBy: i + 1)
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
