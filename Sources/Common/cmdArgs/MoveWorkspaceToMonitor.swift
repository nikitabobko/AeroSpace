public struct MoveWorkspaceToMonitorCmdArgs: RawCmdArgs {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveWorkspaceToMonitor,
        allowInConfig: true,
        help: """
            USAGE: move-workspace-to-monitor [-h|--help] --wrap-around (next|prev)

            OPTIONS:
              -h, --help           Print help
              --wrap-around        Allows to move workspace between first and last monitors
            """,
        options: [
            "--wrap-around": trueBoolFlag(\.wrapAround)
        ],
        arguments: [newArgParser(\.target, parseMonitorTarget, mandatoryArgPlaceholder: "(next|prev)")]
    )

    public var wrapAround: Bool = false

    public var target: Lateinit<MoveWorkspaceToMonitorCmdArgs.MonitorTarget> = .uninitialized // todo introduce --wrap-around flag
    public enum MonitorTarget: String, CaseIterable {
        case next, prev
    }

    fileprivate init() {}
}

public func parseMoveWorkspaceToMonitorCmdArgs(_ args: [String]) -> ParsedCmd<MoveWorkspaceToMonitorCmdArgs> {
    parseRawCmdArgs(MoveWorkspaceToMonitorCmdArgs(), args)
        .filter(
            """
            Migration error: --wrap-around flag is mandatory for move-workspace-to-monitor command.

            Reason:
            - Until 0.8.0, move-workspace-to-monitor didn't have --wrap-around flag but it's behavior was effectively enabled by default.
            - In future versions of AeroSpace, the default will change.
              (to make 'move-workspace-to-monitor' consistent with 'workspace (next|prev)' and 'move-node-to-workspace (next|prev)')
            - To make sure that the default doesn't change silently the migration error is reported.
            """
        ) { raw in raw.wrapAround == true }
}

private func parseMonitorTarget(arg: String, nextArgs: inout [String]) -> Parsed<MoveWorkspaceToMonitorCmdArgs.MonitorTarget> {
    parseEnum(arg, MoveWorkspaceToMonitorCmdArgs.MonitorTarget.self)
}
