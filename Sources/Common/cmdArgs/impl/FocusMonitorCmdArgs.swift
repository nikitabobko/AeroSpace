public struct FocusMonitorCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .focusMonitor,
        help: focus_monitor_help_generated,
        flags: [
            "--wrap-around": trueBoolFlag(\.wrapAround),
        ],
        posArgs: [
            dashDashArg(mandatory: false),
            newMandatoryPosArgParser(\.target, parseMonitorTarget, placeholder: MonitorTarget.cases.joinedCliArgs),
        ],
    )

    public var wrapAround: Bool = false
    public var target: Lateinit<MonitorTarget> = .uninitialized
}

func parseFocusMonitorCmdArgs(_ args: StrArrSlice) -> ParsedCmd<FocusMonitorCmdArgs> {
    parseSpecificCmdArgs(FocusMonitorCmdArgs(rawArgs: args), args)
        .filter("--wrap-around is incompatible with <monitor-pattern> argument") { !$0.wrapAround || !$0.target.val.isPatterns }
}

func parseMonitorTarget(i: PosArgParserInput) -> ParsedCliArgs<MonitorTarget> {
    switch (i.arg, i.sawDashDash) {
        case ("next", false):
            return .succ(.relative(.next), advanceBy: 1)
        case ("prev", false):
            return .succ(.relative(.prev), advanceBy: 1)
        case ("left", false):
            return .succ(.direction(.left), advanceBy: 1)
        case ("down", false):
            return .succ(.direction(.down), advanceBy: 1)
        case ("up", false):
            return .succ(.direction(.up), advanceBy: 1)
        case ("right", false):
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
