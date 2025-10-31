public struct MoveWorkspaceToMonitorCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveWorkspaceToMonitor,
        allowInConfig: true,
        help: move_workspace_to_monitor_help_generated,
        flags: [
            "--wrap-around": trueBoolFlag(\.wrapAround),
            "--workspace": optionalWorkspaceFlag(),
        ],
        posArgs: [
            newArgParser(\.target, parseTarget, mandatoryArgPlaceholder: MonitorTarget.cases.joinedCliArgs),
        ],
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
    public var wrapAround: Bool = false
    public var target: Lateinit<MonitorTarget> = .uninitialized
}

public func parseWorkspaceToMonitorCmdArgs(_ args: StrArrSlice) -> ParsedCmd<MoveWorkspaceToMonitorCmdArgs> {
    parseSpecificCmdArgs(MoveWorkspaceToMonitorCmdArgs(rawArgs: args), args)
        .filter("--wrap-around is incompatible with <monitor-pattern> argument") {
            $0.wrapAround.implies(!$0.target.val.isPatterns)
        }
}
