public struct MoveWorkspaceToMonitorCmdArgs: RawCmdArgs {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveWorkspaceToMonitor,
        allowInConfig: true,
        help: """
              USAGE: move-workspace-to-monitor [-h|--help] (next|prev)

              OPTIONS:
                -h, --help              Print help
              """,
        options: [:],
        arguments: [newArgParser(\.target, parseMonitorTarget, mandatoryArgPlaceholder: "(next|prev)")]
    )

    public var target: Lateinit<MoveWorkspaceToMonitorCmdArgs.MonitorTarget> = .uninitialized // todo introduce --wrap-around flag
    public enum MonitorTarget: String, CaseIterable {
        case next, prev
    }

    fileprivate init() {}
}

public func parseMoveWorkspaceToMonitorCmdArgs(_ args: [String]) -> ParsedCmd<MoveWorkspaceToMonitorCmdArgs> {
    parseRawCmdArgs(MoveWorkspaceToMonitorCmdArgs(), args)
}

private func parseMonitorTarget(arg: String, nextArgs: inout [String]) -> Parsed<MoveWorkspaceToMonitorCmdArgs.MonitorTarget> {
    parseEnum(arg, MoveWorkspaceToMonitorCmdArgs.MonitorTarget.self)
}
