import OrderedCollections

private let orkspace = "<workspace>"
private let _workspaces = "\(orkspace)..."

public struct ListWindowsCmdArgs: RawCmdArgs, CmdArgs, Equatable {
    public let rawArgs: EquatableNoop<[String]>
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listWindows,
        allowInConfig: false,
        help: """
            USAGE: list-windows [-h|--help] (--workspace \(_workspaces)|--monitor \(_monitors))
                                [--monitor \(_monitors)] [--workspace \(_workspaces)]
                                [--pid <pid>] [--app-id <app-id>]
               OR: list-windows [-h|--help] --all
               OR: list-windows [-h|--help] --focused

            OPTIONS:
              -h, --help                      Print help
              --all                           Alias for "--monitor all"
              --focused                       Print the focused window
              --workspace \(_workspaces)      Filter results to only print windows that belong to specified workspaces
              --monitor \(_monitors)          Filter results to only print the windows that are attached to specified monitors
              --pid <pid>                     Filter results to only print windows that belong to the Application with specified <pid>
              --app-id <app-id>               Filter results to only print windows that belong to the Application with specified Bundle ID
            """,
        options: [
            "--focused": trueBoolFlag(\.focused),
            "--all": trueBoolFlag(\.all),

            "--monitor": ArgParser(\.monitors, parseMonitorIds),
            "--workspace": ArgParser(\.workspaces, parseWorkspaces),
            "--pid": singleValueOption(\.pidFilter, "<pid>", Int32.init),
            "--app-id": singleValueOption(\.appIdFilter, "<app-id>", { $0 })
        ],
        arguments: []
    )

    fileprivate var all: Bool = false // ALIAS
    public var focused: Bool = false

    public var monitors: [MonitorId] = []
    public var workspaces: [WorkspaceFilter] = []
    public var pidFilter: Int32?
    public var appIdFilter: String?
}

public func parseRawListWindowsCmdArgs(_ args: [String]) -> ParsedCmd<ListWindowsCmdArgs> {
    parseRawCmdArgs(ListWindowsCmdArgs(rawArgs: .init(args)), args)
        .flatMap { raw in
            var conflicting: OrderedSet<String> = []
            if (raw.all) { conflicting.insert("--all", at: 0) }
            if (raw.focused) { conflicting.insert("--focused", at: 0) }
            if (!raw.workspaces.isEmpty) { conflicting.insert("--workspace", at: 0) }
            else if (!raw.monitors.isEmpty) { conflicting.insert("--monitor", at: 0) }
            return switch conflicting.count {
                case 1: .cmd(raw)
                case 0: .failure("Mandatory option is not specified (--focused|--all|--monitor|--workspace)")
                default: .failure("Conflicting options: \(conflicting.joined(separator: ", "))")
            }
        }
        .filter("--all conflicts with all other flags") { raw in
            !raw.all || raw == ListWindowsCmdArgs(rawArgs: .init([]), all: true)
        }
        .filter("--focused conflicts with all other flags") { raw in
            !raw.focused || raw == ListWindowsCmdArgs(rawArgs: .init(args), focused: true)
        }
        .map { raw in
            // Normalize alias
            raw.all ? ListWindowsCmdArgs(rawArgs: .init(args), monitors: [.all]) : raw
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
        if workspaceRaw == "visible" {
            workspaces.append(.visible)
        } else if workspaceRaw == "focused" {
            workspaces.append(.focused)
        } else {
            switch WorkspaceName.parse(workspaceRaw) {
                case .success(let unwrapped):
                    workspaces.append(.name(unwrapped))
                case .failure(let msg):
                    return .failure(msg)
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
