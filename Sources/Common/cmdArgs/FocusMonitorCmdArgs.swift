public struct FocusMonitorCmdArgs: RawCmdArgs, CmdArgs {
    fileprivate init() {}
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .focusMonitor,
        allowInConfig: true,
        help: """
              USAGE: focus-monitor [-h|--help] [--wrap-around] (left|down|up|right)
                 OR: focus-monitor [-h|--help] [--wrap-around] (next|prev)
                 OR: focus-monitor [-h|--help] <monitor-pattern>...

              OPTIONS:
                -h, --help            Print help
                --wrap-around         Make it possible to wrap around focus

              ARGUMENTS:
                (left|down|up|right)  Focus monitor in direction relative to the currently focused monitor
                (next|prev)           Focus next|prev monitor in order they appear in tray icon
                <monitor-pattern>     Find the first monitor pattern in the list that
                                      doesn't describe the current monitor and focus the appropriate monitor.
                                      Monitor pattern is the same as in `workspace-to-monitor-force-assignment`
                                      config option
              """,
        options: [
            "--wrap-around": trueBoolFlag(\.wrapAround)
        ],
        arguments: [newArgParser(\.target, parseTarget, mandatoryArgPlaceholder: "(left|down|up|right|next|prev|<monitor-pattern>)")]
    )

    public var wrapAround: Bool = false
    public var target: Lateinit<MonitorTarget> = .uninitialized
}

public func parseFocusMonitorCmdArgs(_ args: [String]) -> ParsedCmd<FocusMonitorCmdArgs> {
    parseRawCmdArgs(FocusMonitorCmdArgs(), args)
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

public enum MonitorTarget {
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
