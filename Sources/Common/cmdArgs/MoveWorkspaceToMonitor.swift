public struct MoveWorkspaceToMonitorCmdArgs: RawCmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveWorkspaceToMonitor,
        allowInConfig: true,
        help: """
            USAGE: move-workspace-to-monitor [-h|--help] [--wrap-around] (next|prev)

            OPTIONS:
              -h, --help           Print help
              --wrap-around        Allows to move workspace between first and last monitors
            """,
        options: [
            "--wrap-around": trueBoolFlag(\.wrapAround),
        ],
        arguments: [newArgParser(\.target, parseMonitorTarget, mandatoryArgPlaceholder: "(next|prev)")]
    )

    public var windowId: UInt32?
    public var workspaceName: String?
    public var wrapAround: Bool = false
    public var target: Lateinit<MoveWorkspaceToMonitorCmdArgs.MonitorTarget> = .uninitialized
    public enum MonitorTarget: String, CaseIterable {
        case next, prev
    }
}

private func parseMonitorTarget(arg: String, nextArgs: inout [String]) -> Parsed<MoveWorkspaceToMonitorCmdArgs.MonitorTarget> {
    parseEnum(arg, MoveWorkspaceToMonitorCmdArgs.MonitorTarget.self)
}
