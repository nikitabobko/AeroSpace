private struct RawMoveWorkspaceToMonitorCmdArgs: RawCmdArgs {
    var monitorTarget: MoveWorkspaceToMonitorCmdArgs.MonitorTarget?

    static let info = CmdInfo<Self>(
        help: """
              USAGE: move-workspace-to-monitor [-h|--help] (next|prev)

              OPTIONS:
                -h, --help              Print help
              """,
        options: [:],
        arguments: [ArgParser(\.monitorTarget, parseMonitorTarget)]
    )
}

struct MoveWorkspaceToMonitorCmdArgs: CmdArgs {
    let kind: CmdKind = .moveWorkspaceToMonitor
    let target: MonitorTarget
    enum MonitorTarget: String, CaseIterable {
        case next, prev
    }
}

func parseMoveWorkspaceToMonitorCmdArgs(_ args: [String]) -> ParsedCmd<MoveWorkspaceToMonitorCmdArgs> {
    parseRawCmdArgs(RawMoveWorkspaceToMonitorCmdArgs(), args)
        .flatMap { raw in
            guard let target = raw.monitorTarget else {
                return .failure("<workspace-name> is mandatory argument")
            }
            return .cmd(MoveWorkspaceToMonitorCmdArgs(
                target: target
            ))
        }
}

private func parseMonitorTarget(_ arg: String) -> Parsed<MoveWorkspaceToMonitorCmdArgs.MonitorTarget> {
    parseEnum(arg, MoveWorkspaceToMonitorCmdArgs.MonitorTarget.self)
}
