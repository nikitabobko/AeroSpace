public struct MoveNodeToMonitorCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveNodeToMonitor,
        allowInConfig: true,
        help: """
            USAGE: move-node-to-monitor [-h|--help] [--wrap-around] (left|down|up|right)
               OR: move-node-to-monitor [-h|--help] [--wrap-around] (next|prev)
               OR: move-node-to-monitor [-h|--help] <monitor-pattern>...
            """,
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

public func parseMoveNodeToMonitorCmdArgs(_ args: [String]) -> ParsedCmd<MoveNodeToMonitorCmdArgs> {
    parseSpecificCmdArgs(MoveNodeToMonitorCmdArgs(rawArgs: args), args)
        .filter("--wrap-around is incompatible with <monitor-pattern> argument") { !$0.wrapAround || !$0.target.val.isPatterns }
}
