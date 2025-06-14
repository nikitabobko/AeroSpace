public struct MoveNodeToMonitorCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveNodeToMonitor,
        allowInConfig: true,
        help: move_node_to_monitor_help_generated,
        options: [
            // "Own" option
            "--wrap-around": trueBoolFlag(\.wrapAround),

            // Forward to moveNodeToWorkspace
            "--window-id": optionalWindowIdFlag(),
            "--focus-follows-window": trueBoolFlag(\.moveNodeToWorkspace.focusFollowsWindow),
            "--fail-if-noop": trueBoolFlag(\.moveNodeToWorkspace.failIfNoop),
        ],
        arguments: [newArgParser(\.target, parseTarget, mandatoryArgPlaceholder: MonitorTarget.cases.joinedCliArgs)]
    )

    public init(target: MonitorTarget) {
        self.rawArgs = .init([])
        self.target = .initialized(target)
    }

    /*conforms*/ public var workspaceName: WorkspaceName?
    /*conforms*/ public var windowId: UInt32? { // Forward to moveNodeToWorkspace
        get { moveNodeToWorkspace.windowId }
        set(newValue) { moveNodeToWorkspace.windowId = newValue }
    }

    public var moveNodeToWorkspace = MoveNodeToWorkspaceCmdArgs(rawArgs: [])
    public var wrapAround: Bool = false
    public var target: Lateinit<MonitorTarget> = .uninitialized
}

public func parseMoveNodeToMonitorCmdArgs(_ args: [String]) -> ParsedCmd<MoveNodeToMonitorCmdArgs> {
    parseSpecificCmdArgs(MoveNodeToMonitorCmdArgs(rawArgs: args), args)
        .filter("--wrap-around is incompatible with <monitor-pattern> argument") { $0.wrapAround.implies(!$0.target.val.isPatterns) }
        .filter("--fail-if-noop is incompatible with \(MonitorTarget.casesExceptPatterns.joinedCliArgs)") { $0.moveNodeToWorkspace.failIfNoop.implies($0.target.val.isPatterns) }
}
