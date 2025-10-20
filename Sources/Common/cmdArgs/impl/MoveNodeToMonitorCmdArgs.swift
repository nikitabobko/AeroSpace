public struct MoveNodeToMonitorCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    fileprivate init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveNodeToMonitor,
        allowInConfig: true,
        help: move_node_to_monitor_help_generated,
        flags: [
            // "Own" option
            "--wrap-around": trueBoolFlag(\.wrapAround),

            "--window-id": optionalWindowIdFlag(),
            "--focus-follows-window": trueBoolFlag(\.focusFollowsWindow),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        posArgs: [newArgParser(\.target, parseTarget, mandatoryArgPlaceholder: MonitorTarget.cases.joinedCliArgs)],
    )

    public init(target: MonitorTarget) {
        self.rawArgsForStrRepr = .init([])
        self.target = .initialized(target)
    }

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?

    public var failIfNoop: Bool = false
    public var focusFollowsWindow: Bool = false
    public var wrapAround: Bool = false
    public var target: Lateinit<MonitorTarget> = .uninitialized
}

public func parseMoveNodeToMonitorCmdArgs(_ args: StrArrSlice) -> ParsedCmd<MoveNodeToMonitorCmdArgs> {
    parseSpecificCmdArgs(MoveNodeToMonitorCmdArgs(rawArgs: args), args)
        .filter("--wrap-around is incompatible with <monitor-pattern> argument") { $0.wrapAround.implies(!$0.target.val.isPatterns) }
        .filter("--fail-if-noop is incompatible with \(MonitorTarget.casesExceptPatterns.joinedCliArgs)") { $0.failIfNoop.implies($0.target.val.isPatterns) }
}
