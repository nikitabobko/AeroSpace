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
            "--focused": trueBoolFlag(\.focused),
            "--all": trueBoolFlag(\.all),

            "--monitor": ArgParser(\.monitors, parseMonitorIds),
            "--workspace": ArgParser(\.workspaces, parseWorkspaces),
            "--pid": singleValueOption(\.pidFilter, "<pid>", Int32.init),
            "--app-bundle-id": singleValueOption(\.appIdFilter, "<app-bundle-id>") { $0 },
            "--format": ArgParser(\.format, parseFormat),
            "--count": trueBoolFlag(\.outputOnlyCount),
        ],
        arguments: [],
        conflictingOptions: [
            ["--format", "--count"],
        ]
    )

    fileprivate var all: Bool = false // ALIAS

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
    public var focused: Bool = false
    public var monitors: [MonitorId] = []
    public var workspaces: [WorkspaceFilter] = []
    public var pidFilter: Int32?
    public var appIdFilter: String?
    public var format: [StringInterToken] = [
        .value("window-id"), .value("right-padding"), .literal(" | "),
        .value("app-name"), .value("right-padding"), .literal(" | "),
        .value("window-title"),
    ]
    public var outputOnlyCount: Bool = false
}

public func parseRawListWindowsCmdArgs(_ args: [String]) -> ParsedCmd<ListWindowsCmdArgs> {
    let args = args.map { $0 == "--app-id" ? "--app-bundle-id" : $0 } // Compatibility
    return parseSpecificCmdArgs(ListWindowsCmdArgs(rawArgs: .init(args)), args)
        .flatMap { raw in
            var conflicting: OrderedSet<String> = []
            if (raw.all) { conflicting.insert("--all", at: 0) }
            if (raw.focused) { conflicting.insert("--focused", at: 0) }
            if (!raw.workspaces.isEmpty) {
                conflicting.insert("--workspace", at: 0)
            } else if (!raw.monitors.isEmpty) {
                conflicting.insert("--monitor", at: 0)
            }
            return switch conflicting.count {
                case 1: .cmd(raw)
                case 0: .failure("Mandatory option is not specified (--focused|--all|--monitor|--workspace)")
                default: .failure("Conflicting options: \(conflicting.joined(separator: ", "))")
            }
        }
        .filter("--all conflicts with \"filtering\" flags. Please use '--monitor all'") { raw in
            !raw.all || raw == ListWindowsCmdArgs(rawArgs: .init([]), all: true, format: raw.format, outputOnlyCount: raw.outputOnlyCount)
        }
        .filter("--focused conflicts with \"filtering\" flags") { raw in
            !raw.focused || raw == ListWindowsCmdArgs(rawArgs: .init(args), focused: true, format: raw.format, outputOnlyCount: raw.outputOnlyCount)
        }
        .map { raw in
            // Normalize alias
            raw.all ? ListWindowsCmdArgs(rawArgs: .init(args), monitors: [.all], format: raw.format, outputOnlyCount: raw.outputOnlyCount) : raw
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
