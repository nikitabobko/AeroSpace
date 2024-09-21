public struct MoveNodeToWorkspaceCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public var target: Lateinit<WorkspaceTarget> = .uninitialized
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveNodeToWorkspace,
        allowInConfig: true,
        help: move_node_to_workspace_help_generated,
        options: [
            "--wrap-around": optionalTrueBoolFlag(\._wrapAround),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        arguments: [newArgParser(\.target, parseWorkspaceTarget, mandatoryArgPlaceholder: workspaceTargetPlaceholder)]
    )

    public var _wrapAround: Bool?
    public var failIfNoop: Bool = false
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?

    public init(rawArgs: [String]) {
        self.rawArgs = .init(rawArgs)
    }
}

public extension MoveNodeToWorkspaceCmdArgs {
    var wrapAround: Bool { _wrapAround ?? false }
}

func implication(ifTrue: Bool, mustHold: @autoclosure () -> Bool) -> Bool { !ifTrue || mustHold() }

public func parseMoveNodeToWorkspaceCmdArgs(_ args: [String]) -> ParsedCmd<MoveNodeToWorkspaceCmdArgs> {
    parseSpecificCmdArgs(MoveNodeToWorkspaceCmdArgs(rawArgs: .init(args)), args)
        .filter("--wrapAround requires using (prev|next) argument") { ($0._wrapAround != nil).implies($0.target.val.isRelatve) }
        .filterNot("--fail-if-noop is incompatible with (next|prev)") { $0.failIfNoop && $0.target.val.isRelatve }
}
