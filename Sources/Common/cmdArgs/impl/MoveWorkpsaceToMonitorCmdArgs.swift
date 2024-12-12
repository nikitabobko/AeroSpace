public struct MoveWorkspaceToMonitorCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveWorkspaceToMonitor,
        allowInConfig: true,
        help: move_workspace_to_monitor_help_generated,
        options: [
            "--wrap-around": trueBoolFlag(\.wrapAround),
            "--workspace": optionalWorkspaceFlag(),
        ],
        arguments: [newArgParser(\.target, parseMonitorTarget, mandatoryArgPlaceholder: "(next|prev|reset)")]
    )

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
    public var wrapAround: Bool = false
    public var target: Lateinit<MoveWorkspaceToMonitorCmdArgs.MonitorTarget> = .uninitialized
    public enum MonitorTarget: String, CaseIterable {
        case next, prev, reset
    }
}

private func parseMonitorTarget(arg: String, nextArgs: inout [String]) -> Parsed<MoveWorkspaceToMonitorCmdArgs.MonitorTarget> {
    parseEnum(arg, MoveWorkspaceToMonitorCmdArgs.MonitorTarget.self)
}
