public struct FocusMonitorCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .focusMonitor,
        allowInConfig: true,
        help: focus_monitor_help_generated,
        options: [
            "--wrap-around": trueBoolFlag(\.wrapAround),
        ],
        arguments: [newArgParser(\.target, parseTarget, mandatoryArgPlaceholder: "(left|down|up|right|next|prev|<monitor-pattern>)")]
    )

    public var wrapAround: Bool = false
    public var target: Lateinit<MonitorTarget> = .uninitialized
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}

public func parseFocusMonitorCmdArgs(_ args: [String]) -> ParsedCmd<FocusMonitorCmdArgs> {
    parseSpecificCmdArgs(FocusMonitorCmdArgs(rawArgs: args), args)
        .filter("--wrap-around is incompatible with <monitor-pattern> argument") { !$0.wrapAround || !$0.target.val.isPatterns }
}

func parseTarget(_ arg: String, _ nextArgs: inout [String]) -> Parsed<MonitorTarget> {
    switch arg {
        case "next":
            return .success(.relative(.next))
        case "prev":
            return .success(.relative(.prev))
        case "left":
            return .success(.directional(.left))
        case "down":
            return .success(.directional(.down))
        case "up":
            return .success(.directional(.up))
        case "right":
            return .success(.directional(.right))
        default:
            let args: [String] = [arg] + nextArgs.allNextNonFlagArgs()
            return args.mapAllOrFailure(parseMonitorDescription).map { .patterns($0) }
    }
}

public enum NextPrev: Equatable {
    case next, prev
}

public enum MonitorTarget: Equatable {
    case directional(CardinalDirection)
    case relative(NextPrev)
    case patterns([MonitorDescription])

    var isPatterns: Bool {
        if case .patterns = self {
            return true
        } else {
            return false
        }
    }
}
