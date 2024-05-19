private let orkspace = "<workspace>"
private let _workspaces = "\(orkspace)..."

private struct RawListWindowsCmdArgs: RawCmdArgs, Equatable {
    public let rawArgs: EquatableNoop<[String]>
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listWindows,
        allowInConfig: false,
        help: """
            USAGE: list-windows [-h|--help] (--workspace \(_workspaces)|--monitor \(_monitors))
                                [--monitor \(_monitors)] [--workspace \(_workspaces)]
                                [--pid <pid>] [--app-id <app-id>] [--macos-native-hidden-app [no]]
                                [--macos-native-minimized] [--macos-native-fullscreen]
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
              --macos-native-hidden-app [no]  Filter results to only print windows that belong to hidden applications.
                                              [no] inverts the condition
              --macos-native-minimized [no]   Filter results to only print minimized windows. [no] inverts the condition
              --macos-native-fullscreen [no]  Filter results to only print fullscreen windows. [no] inverts the condition
            """,
        options: [
            "--focused": trueBoolFlag(\.focused),
            "--all": trueBoolFlag(\.all),

            "--monitor": ArgParser(\.manual.monitors, parseMonitorIds),
            "--workspace": ArgParser(\.manual.workspaces, parseWorkspaces),
            "--pid": singleValueOption(\.manual.pidFilter, "<pid>", Int32.init),
            "--macos-native-hidden-app": boolFlag(\.manual.macosHiddenApp),
            "--macos-native-minimized": boolFlag(\.manual.macosMinimized),
            "--macos-native-fullscreen": boolFlag(\.manual.macosFullscreen),
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
        if !manual.monitors.isEmpty || !manual.workspaces.isEmpty {
            if !manual.monitors.isEmpty {
                result.append("--monitor")
            } else {
                result.append("--workspace")
            }
        }
        return result
    }
}

public enum ListWindowsCmdArgs: CmdArgs {
    public static var info: CmdStaticInfo = RawListWindowsCmdArgs.info

    case focused(rawArgs: [String])
    case manual(rawArgs: [String], ManualFilter)

    public var rawArgs: EquatableNoop<[String]> {
        switch self {
            case .focused(let rawArgs): .init(rawArgs)
            case .manual(let rawArgs, _): .init(rawArgs)
        }
    }

    public struct ManualFilter: Equatable {
        public var monitors: [MonitorId] = []
        public var workspaces: [WorkspaceFilter] = []
        public var pidFilter: Int32?
        public var appIdFilter: String?
        public var macosHiddenApp: Bool?
        public var macosMinimized: Bool?
        public var macosFullscreen: Bool?
    }
}

public func parseListWindowsCmdArgs(_ args: [String]) -> ParsedCmd<ListWindowsCmdArgs> {
    parseRawCmdArgs(RawListWindowsCmdArgs(rawArgs: .init(args)), args)
        .filter("Specified flags require explicit (--workspace|--monitor)") {
            $0.manual == .init() || !$0.manual.workspaces.isEmpty || !$0.manual.monitors.isEmpty
        }
        .flatMap { raw in
            let uniqueOptions = raw.uniqueOptions
            return switch uniqueOptions.count {
                case 1:  .cmd(raw)
                case 0:  .failure("'list-windows' mandatory option is not specified (--focused|--all|--monitor|--workspace)")
                default: .failure("Conflicting options: \(uniqueOptions.joined(separator: ", "))")
            }
        }
        .flatMap { raw in
            if raw.all {
                return .cmd(.manual(rawArgs: args, ListWindowsCmdArgs.ManualFilter(monitors: [.all])))
            } else if raw.focused {
                return .cmd(.focused(rawArgs: args))
            } else {
                return .cmd(.manual(rawArgs: args, raw.manual))
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
