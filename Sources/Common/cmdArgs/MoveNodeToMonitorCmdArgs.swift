public struct MoveNodeToMonitorCmdArgs: RawCmdArgs, CmdArgs, Equatable {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveNodeToMonitor,
        allowInConfig: true,
        help: """
            USAGE: move-node-to-monitor [-h|--help] [--wrap-around] (left|down|up|right)
               OR: move-node-to-monitor [-h|--help] [--wrap-around] (next|prev)
               OR: move-node-to-monitor [-h|--help] <monitor-pattern>...

            OPTIONS:
              -h, --help            Print help
              --wrap-around         Make it possible to wrap around the movement

            ARGUMENTS:
              (left|down|up|right)  Move window to monitor in direction relative to the focused monitor
              (next|prev)           Move window to next|prev monitor in order they appear in tray icon
              <monitor-pattern>     Find the first monitor pattern in the list that
                                    doesn't describe the current monitor and move the window
                                    to the appropriate monitor. Monitor pattern is the same as in
                                    `workspace-to-monitor-force-assignment` config option
            """,
        options: [
            "--wrap-around": trueBoolFlag(\.wrapAround),
        ],
        arguments: [newArgParser(\.target, parseTarget, mandatoryArgPlaceholder: "(left|down|up|right|next|prev|<monitor-pattern>)")]
    )

    public var wrapAround: Bool = false
    public var target: Lateinit<MonitorTarget> = .uninitialized
    public var windowId: UInt32?
    public var workspaceName: String?
}

public func parseMoveNodeToMonitorCmdArgs(_ args: [String]) -> ParsedCmd<MoveNodeToMonitorCmdArgs> {
    parseRawCmdArgs(MoveNodeToMonitorCmdArgs(rawArgs: args), args)
        .filter("--wrap-around is incompatible with <monitor-pattern> argument") { !$0.wrapAround || !$0.target.val.isPatterns }
}
