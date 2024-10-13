import OrderedCollections

private let orkspace = "<workspace>" // todo
private let _workspaces = "\(orkspace)..."

public struct ListWindowsCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listWindows,
        allowInConfig: false,
        help: list_windows_help_generated,
        options: [
            "--all": trueBoolFlag(\.all),

            "--focused": trueBoolFlag(\.filteringOptions.focused),
            "--monitor": ArgParser(\.filteringOptions.monitors, parseMonitorIds),
            "--workspace": ArgParser(\.filteringOptions.workspaces, parseWorkspaces),
            "--pid": singleValueOption(\.filteringOptions.pidFilter, "<pid>", Int32.init),
            "--app-bundle-id": singleValueOption(\.filteringOptions.appIdFilter, "<app-bundle-id>") { $0 },

            "--format": ArgParser(\._format, parseFormat),
            "--count": trueBoolFlag(\.outputOnlyCount),
        ],
        arguments: [],
        conflictingOptions: [
            ["--all", "--focused", "--workspace"],
            ["--all", "--focused", "--monitor"],
            ["--format", "--count"],
        ]
    )

    fileprivate var all: Bool = false // ALIAS

    public var filteringOptions = FilteringOptions()
    public var _format: [StringInterToken] = []
    public var outputOnlyCount: Bool = false

    public var windowId: UInt32?               // unused
    public var workspaceName: WorkspaceName?   // unused

    public struct FilteringOptions: Copyable, Equatable {
        public var monitors: [MonitorId] = []
        public var focused: Bool = false
        public var workspaces: [WorkspaceFilter] = []
        public var pidFilter: Int32?
        public var appIdFilter: String?
    }
}

public extension ListWindowsCmdArgs {
    var format: [StringInterToken] {
        _format.isEmpty
            ? [
                .value("window-id"), .value("right-padding"), .literal(" | "),
                .value("app-name"), .value("right-padding"), .literal(" | "),
                .value("window-title"),
            ]
            : _format
    }
}

public func parseRawListWindowsCmdArgs(_ args: [String]) -> ParsedCmd<ListWindowsCmdArgs> {
    let args = args.map { $0 == "--app-id" ? "--app-bundle-id" : $0 } // Compatibility
    return parseSpecificCmdArgs(ListWindowsCmdArgs(rawArgs: .init(args)), args)
        .filter("Mandatory option is not specified (--focused|--all|--monitor|--workspace)") { raw in
            raw.filteringOptions.focused || raw.all || !raw.filteringOptions.monitors.isEmpty || !raw.filteringOptions.workspaces.isEmpty
        }
        .filter("--all conflicts with \"filtering\" flags. Please use '--monitor all' instead of '--all' alias") { raw in
            raw.all.implies(raw.filteringOptions == ListWindowsCmdArgs.FilteringOptions())
        }
        .filter("--focused conflicts with other \"filtering\" flags") { raw in
            raw.filteringOptions.focused.implies(raw.filteringOptions.copy(\.focused, false) == ListWindowsCmdArgs.FilteringOptions())
        }
        .map { raw in
            raw.all ? raw.copy(\.filteringOptions.monitors, [.all]).copy(\.all, false) : raw // Normalize alias
        }
}

func parseFormat(arg: String, nextArgs: inout [String]) -> Parsed<[StringInterToken]> {
    return if let nextArg = nextArgs.nextNonFlagOrNil() {
        switch nextArg.interpolationTokens(interpolationChar: "%") {
            case .success(let tokens): .success(tokens)
            case .failure(let err): .failure("Failed to parse <output-format>. \(err)")
        }
    } else {
        .failure("<output-format> is mandatory")
    }
}

private func parseWorkspaces(arg: String, nextArgs: inout [String]) -> Parsed<[WorkspaceFilter]> {
    let args = nextArgs.allNextNonFlagArgs()
    let possibleValues = "\(orkspace) possible values: (<workspace-name>|focused|visible)"
    if args.isEmpty {
        return .failure("\(_workspaces) is mandatory. \(possibleValues)")
    }
    var workspaces: [WorkspaceFilter] = []
    for workspaceRaw: String in args {
        switch workspaceRaw {
            case "visible": workspaces.append(.visible)
            case "focused": workspaces.append(.focused)
            default:
                switch WorkspaceName.parse(workspaceRaw) {
                    case .success(let unwrapped): workspaces.append(.name(unwrapped))
                    case .failure(let msg): return .failure(msg)
                }
        }
    }
    return .success(workspaces)
}

public enum WorkspaceFilter: Equatable {
    case focused
    case visible
    case name(WorkspaceName)
}
