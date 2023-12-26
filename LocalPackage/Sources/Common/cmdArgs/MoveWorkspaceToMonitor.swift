private struct RawMoveWorkspaceToMonitorCmdArgs: RawCmdArgs {
    var monitorTarget: Lateinit<MoveWorkspaceToMonitorCmdArgs.MonitorTarget> = .uninitialized // todo introduce --wrap-around flag

    static let parser: CmdParser<Self> = cmdParser(
        kind: .moveWorkspaceToMonitor,
        allowInConfig: true,
        help: """
              USAGE: move-workspace-to-monitor [-h|--help] (next|prev)

              OPTIONS:
                -h, --help              Print help
              """,
        options: [:],
        arguments: [newArgParser(\.monitorTarget, parseMonitorTarget, argPlaceholderIfMandatory: "(next|prev)")]
    )
}

public struct MoveWorkspaceToMonitorCmdArgs: CmdArgs {
    public static let info: CmdStaticInfo = RawMoveWorkspaceToMonitorCmdArgs.info

    public let target: MonitorTarget
    public enum MonitorTarget: String, CaseIterable {
        case next, prev
    }
}

public func parseMoveWorkspaceToMonitorCmdArgs(_ args: [String]) -> ParsedCmd<MoveWorkspaceToMonitorCmdArgs> {
    parseRawCmdArgs(RawMoveWorkspaceToMonitorCmdArgs(), args)
        .flatMap { raw in .cmd(MoveWorkspaceToMonitorCmdArgs(target: raw.monitorTarget.val)) }
}

private func parseMonitorTarget(arg: String, nextArgs: inout [String]) -> Parsed<MoveWorkspaceToMonitorCmdArgs.MonitorTarget> {
    parseEnum(arg, MoveWorkspaceToMonitorCmdArgs.MonitorTarget.self)
}
