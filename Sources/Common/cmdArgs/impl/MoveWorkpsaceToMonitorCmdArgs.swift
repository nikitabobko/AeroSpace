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
        arguments: [
            newArgParser(
                \.target, parseTarget,
                mandatoryArgPlaceholder: "(left|down|up|right|next|prev|<monitor-pattern>)"),
        ]
    )

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
    public var wrapAround: Bool = false
    public var target: Lateinit<MonitorTarget> = .uninitialized
}
public func parseWorkspaceToMonitorCmdArgs(_ args: [String]) -> ParsedCmd<
    MoveWorkspaceToMonitorCmdArgs
> {
    parseSpecificCmdArgs(MoveWorkspaceToMonitorCmdArgs(rawArgs: args), args)
        .filter("--wrap-around is incompatible with <monitor-pattern> argument") {
            $0.wrapAround.implies(!$0.target.val.isPatterns)
        }
}
