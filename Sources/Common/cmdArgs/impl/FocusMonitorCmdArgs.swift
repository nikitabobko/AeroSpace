public struct FocusMonitorCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    fileprivate init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
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

public func parseFocusMonitorCmdArgs(_ args: StrArrSlice) -> ParsedCmd<FocusMonitorCmdArgs> {
    parseSpecificCmdArgs(FocusMonitorCmdArgs(rawArgs: args), args)
        .filter("--wrap-around is incompatible with <monitor-pattern> argument") { !$0.wrapAround || !$0.target.val.isPatterns }
}

func parseTarget(i: ArgParserInput) -> ParsedCliArgs<MonitorTarget> {
    switch i.arg {
        case "next":
            return .succ(.relative(.next), advanceBy: 1)
        case "prev":
            return .succ(.relative(.prev), advanceBy: 1)
        case "left":
            return .succ(.direction(.left), advanceBy: 1)
        case "down":
            return .succ(.direction(.down), advanceBy: 1)
        case "up":
            return .succ(.direction(.up), advanceBy: 1)
        case "right":
            return .succ(.direction(.right), advanceBy: 1)
        default:
            let args = i.nonFlagArgs()
            return .init(args.mapAllOrFailure(parseMonitorDescription).map { .patterns($0) }, advanceBy: args.count)
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
