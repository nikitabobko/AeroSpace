public struct MoveNodeToMonitorCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveNodeToMonitor,
        allowInConfig: true,
        help: move_node_to_monitor_help_generated,
        options: [
            "--wrap-around": trueBoolFlag(\.wrapAround),
            "--window-id": optionalWindowIdFlag(),
            "--focus-follows-window": trueBoolFlag(\.focusFollowsWindow),
        ],
        arguments: [newArgParser(\.target, parseTarget, mandatoryArgPlaceholder: "(left|down|up|right|next|prev|<monitor-pattern>)")]
    )

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?

    public var wrapAround: Bool = false
    public var target: Lateinit<MonitorTarget> = .uninitialized
    public var focusFollowsWindow: Bool = false
}

public func parseMoveNodeToMonitorCmdArgs(_ args: [String]) -> ParsedCmd<MoveNodeToMonitorCmdArgs> {
    parseSpecificCmdArgs(MoveNodeToMonitorCmdArgs(rawArgs: args), args)
        .filter("--wrap-around is incompatible with <monitor-pattern> argument") { !$0.wrapAround || !$0.target.val.isPatterns }
}
