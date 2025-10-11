public struct FocusMonitorCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .focusMonitor,
        allowInConfig: true,
        help: focus_monitor_help_generated,
        flags: [
            "--wrap-around": trueBoolFlag(\.wrapAround),
        ],
        posArgs: [newArgParser(\.target, parseTarget, mandatoryArgPlaceholder: MonitorTarget.cases.joinedCliArgs)],
    )

    public var wrapAround: Bool = false
    public var target: Lateinit<MonitorTarget> = .uninitialized
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
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
            return .success(.direction(.left))
        case "down":
            return .success(.direction(.down))
        case "up":
            return .success(.direction(.up))
        case "right":
            return .success(.direction(.right))
        default:
            let args: [String] = [arg] + nextArgs.allNextNonFlagArgs()
            return args.mapAllOrFailure(parseMonitorDescription).map { .patterns($0) }
    }
}

public enum MonitorTarget: Equatable, Sendable {
    case direction(CardinalDirection)
    case relative(NextPrev)
    case patterns([MonitorDescription])

    var isPatterns: Bool {
        switch self {
            case .patterns: true
            default: false
        }
    }

    static var casesExceptPatterns: [String] { CardinalDirection.cliArgsCases + NextPrev.cliArgsCases }
    static var cases: [String] { casesExceptPatterns + ["<monitor-pattern>"] }

    public var directionOrNil: CardinalDirection? {
        switch self {
            case .direction(let direction): direction
            default: nil
        }
    }
}
