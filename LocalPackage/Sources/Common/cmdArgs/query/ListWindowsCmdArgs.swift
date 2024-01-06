private let orkspace = "<workspace>"
private let _workspaces = "\(orkspace)..."

private struct RawListWindowsCmdArgs: RawCmdArgs, Equatable {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listWindows,
        allowInConfig: false,
        help: """
              USAGE: list-windows [-h|--help] --on-workspaces \(_workspaces) [--on-monitors \(_monitors)]
                                  [--pid <pid>] [--app-id <app-id>]
                 OR: list-windows [-h|--help] --on-monitors \(_monitors) [--on-workspaces \(_workspaces)]
                                  [--pid <pid>] [--app-id <app-id>]
                 OR: list-windows [-h|--help] --all
                 OR: list-windows [-h|--help] --focused

              OPTIONS:
                -h, --help                       Print help
                --all                            Alias for "--on-monitors all"
                --focused                        Print the focused window
                --on-workspaces \(_workspaces)   Filter results to only print windows that belong to specified workspaces
                --on-monitors \(_monitors)       Filter results to only print the windows that are attached to specified monitors
                --pid <pid>                      Filter results to only print windows that belong to the Application with specified <pid>
                --app-id <app-id>                Filter results to only print windows that belong to the Application with specified Bundle ID
              """,
        options: [
            "--focused": trueBoolFlag(\.focused),
            "--all": trueBoolFlag(\.all),

            "--on-monitors": ArgParser(\.manual.onMonitors, parseMonitorIds),
            "--on-workspaces": ArgParser(\.manual.onWorkspaces, parseWorkspaces),
            "--pid": singleValueOption(\.manual.pidFilter, "<pid>", Int32.init),
            "--app-id": singleValueOption(\.manual.appIdFilter, "<app-id>", { $0 })
        ],
        arguments: []
    )

    // ALIAS
    public var all: Bool = false

    public var focused: Bool = false
    public var manual = ListWindowsCmdArgs.ManualFilter()
}

private extension RawListWindowsCmdArgs {
    var uniqueOptions: [String] {
        var result: [String] = []
        if focused { result.append("--focused") }
        if all { result.append("--all") }
        if !manual.onMonitors.isEmpty || !manual.onWorkspaces.isEmpty {
            if !manual.onMonitors.isEmpty {
                result.append("--on-monitors")
            } else {
                result.append("--on-workspaces")
            }
        }
        return result
    }
}

public enum ListWindowsCmdArgs: CmdArgs {
    public static var info: CmdStaticInfo = RawListWindowsCmdArgs.info

    case focused
    case manual(ManualFilter)

    public struct ManualFilter: Equatable {
        public var onMonitors: [MonitorId] = []
        public var onWorkspaces: [WorkspaceFilter] = []
        public var pidFilter: Int32?
        public var appIdFilter: String?
    }
}

public func parseListWindowsCmdArgs(_ args: [String]) -> ParsedCmd<ListWindowsCmdArgs> {
    parseRawCmdArgs(RawListWindowsCmdArgs(), args)
        .filter("Specified flags require explicit (--on-workspaces|--on-monitor)") {
            $0.manual == .init() || !$0.manual.onWorkspaces.isEmpty || !$0.manual.onMonitors.isEmpty
        }
        .flatMap { raw in
            let uniqueOptions = raw.uniqueOptions
            switch uniqueOptions.count {
            case 1:  return .cmd(raw)
            case 0:  return .failure("'list-windows' mandatory option is not specified (--focused|--all|--on-monitors|--on-workspaces)")
            default: return .failure("Conflicting options: \(uniqueOptions.joined(separator: ", "))")
            }
        }
        .flatMap { raw in
            if raw.all {
                return .cmd(.manual(ListWindowsCmdArgs.ManualFilter(onMonitors: [.all])))
            } else if raw.focused {
                return .cmd(.focused)
            } else {
                return .cmd(.manual(raw.manual))
            }
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
