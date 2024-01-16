let onitor = "<monitor>"
let _monitors = "\(onitor)..."

private struct RawListWorkspacesCmdArgs: RawCmdArgs, CmdArgs {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listWorkspaces,
        allowInConfig: false,
        help: """
              USAGE: list-workspaces [-h|--help] --monitor \(_monitors) [--visible [no]] [--empty [no]]
                 OR: list-workspaces [-h|--help] --all
                 OR: list-workspaces [-h|--help] --focused

              OPTIONS:
                -h, --help               Print help
                --all                    Alias for "--monitor all"
                --focused                Alias for "--monitor focused --visible"
                --monitor \(_monitors)   Filter results to only print the workspaces that are attached to specified monitors
                --visible [no]           Filter results to only print currently visible workspaces
                --empty [no]             Filter results to only print empty workspaces. [no] inverts the condition
              """,
        options: [
            "--focused": trueBoolFlag(\.focused),
            "--all": trueBoolFlag(\.all),

            "--visible": boolFlag(\.real.visible),
            "--empty": boolFlag(\.real.empty),
            "--monitor": ArgParser(\.real.onMonitors, parseMonitorIds)
        ],
        arguments: []
    )

    // SHORTCUTS
    var all: Bool = false
    var focused: Bool = false

    // REAL OPTIONS
    var real = ListWorkspacesCmdArgs()
}

public struct ListWorkspacesCmdArgs: CmdArgs, Equatable {
    public static var info: CmdStaticInfo = RawListWorkspacesCmdArgs.info

    public var onMonitors: [MonitorId] = []
    public var visible: Bool?
    public var empty: Bool?
}

private extension RawListWorkspacesCmdArgs {
    var uniqueOptions: [String] {
        var result: [String] = []
        if focused { result.append("--focused") }
        if all { result.append("--all") }
        if !real.onMonitors.isEmpty { result.append("--monitor") }
        return result
    }
}

public func parseListWorkspacesCmdArgs(_ args: [String]) -> ParsedCmd<ListWorkspacesCmdArgs> {
    parseRawCmdArgs(RawListWorkspacesCmdArgs(), args)
        .filter("Specified flags require explicit --monitor") { $0.real == .init() || !$0.real.onMonitors.isEmpty }
        .flatMap { raw in
            let uniqueOptions = raw.uniqueOptions
            switch uniqueOptions.count {
            case 1:
                return .cmd(raw)
            case 0:
                return .failure("'list-workspaces' mandatory option is not specified (--all|--focused|--monitor)")
            default:
                return .failure("Conflicting options: \(uniqueOptions.joined(separator: ", "))")
            }
        }
        .flatMap { raw in
            if raw.focused {
                return .cmd(ListWorkspacesCmdArgs(onMonitors: [.focused], visible: true))
            }
            if raw.all {
                return .cmd(ListWorkspacesCmdArgs(onMonitors: [.all]))
            }
            return .cmd(raw.real)
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
