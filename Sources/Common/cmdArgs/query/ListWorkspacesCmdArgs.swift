import OrderedCollections

let onitor = "<monitor>"
let _monitors = "\(onitor)..."

public struct ListWorkspacesCmdArgs: RawCmdArgs, CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listWorkspaces,
        allowInConfig: false,
        help: """
            USAGE: list-workspaces [-h|--help] --monitor \(_monitors) [--visible [no]] [--empty [no]] [--format <output-format>]
               OR: list-workspaces [-h|--help] --all [--format <output-format>]
               OR: list-workspaces [-h|--help] --focused [--format <output-format>]

            OPTIONS:
              -h, --help                 Print help
              --all                      Alias for "--monitor all"
              --focused                  Alias for "--monitor focused --visible"
              --monitor \(_monitors)     Filter results to only print the workspaces that are attached to specified monitors
              --visible [no]             Filter results to only print currently visible workspaces
              --empty [no]               Filter results to only print empty workspaces. [no] inverts the condition
              --format <output-format>   Specify output format
            """,
        options: [
            "--focused": trueBoolFlag(\.focused),
            "--all": trueBoolFlag(\.all),

            "--visible": boolFlag(\.visible),
            "--empty": boolFlag(\.empty),
            "--monitor": ArgParser(\.onMonitors, parseMonitorIds),
            "--format": ArgParser(\.format, parseFormat),
        ],
        arguments: []
    )

    fileprivate var all: Bool = false // Alias
    fileprivate var focused: Bool = false // Alias

    public var windowId: UInt32?
    public var workspaceName: String?
    public var onMonitors: [MonitorId] = []
    public var visible: Bool?
    public var empty: Bool?
    public var format: [StringInterToken] = [.value("workspace")]
}

public func parseListWorkspacesCmdArgs(_ args: [String]) -> ParsedCmd<ListWorkspacesCmdArgs> {
    parseRawCmdArgs(ListWorkspacesCmdArgs(rawArgs: .init(args)), args)
        .flatMap { raw in
            var conflicting: OrderedSet<String> = []
            if raw.all { conflicting.append("--all") }
            if raw.focused { conflicting.append("--focused") }
            if !raw.onMonitors.isEmpty { conflicting.append("--monitor") }
            return switch conflicting.count {
                case 1: .cmd(raw)
                case 0: .failure("Mandatory option is not specified (--all|--focused|--monitor)")
                default: .failure("Conflicting options: \(conflicting.joined(separator: ", "))")
            }
        }
        .filter("--all conflicts with all other options") { raw in
            !raw.all || raw == ListWorkspacesCmdArgs(rawArgs: .init(args), all: true)
        }
        .map { raw in
            raw.all ? ListWorkspacesCmdArgs(rawArgs: .init(args), onMonitors: [.all]) : raw
        }
        .filter("--focused conflicts with all other options") { raw in
            !raw.focused || raw == ListWorkspacesCmdArgs(rawArgs: .init(args), focused: true)
        }
        .map { raw in
            raw.focused ? ListWorkspacesCmdArgs(rawArgs: .init(args), onMonitors: [.focused], visible: true) : raw
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
