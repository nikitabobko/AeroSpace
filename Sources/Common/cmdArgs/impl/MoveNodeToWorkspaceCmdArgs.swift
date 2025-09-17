public struct MoveNodeToWorkspaceCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveNodeToWorkspace,
        allowInConfig: true,
        help: move_node_to_workspace_help_generated,
        options: [
            "--wrap-around": optionalTrueBoolFlag(\._wrapAround),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
            "--window-id": optionalWindowIdFlag(),
            "--focus-follows-window": trueBoolFlag(\.focusFollowsWindow),

            "--stdin": optionalTrueBoolFlag(\.explicitStdinFlag),
            "--no-stdin": optionalFalseBoolFlag(\.explicitStdinFlag),
        ],
        arguments: [newArgParser(\.target, parseWorkspaceTarget, mandatoryArgPlaceholder: workspaceTargetPlaceholder)],
        conflictingOptions: [
            ["--stdin", "--no-stdin"],
        ],
    )

    public var _wrapAround: Bool?
    public var explicitStdinFlag: Bool? = nil
    public var failIfNoop: Bool = false
    public var focusFollowsWindow: Bool = false
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
    public var target: Lateinit<WorkspaceTarget> = .uninitialized

    public init(rawArgs: [String]) {
        self.rawArgs = .init(rawArgs)
    }
}

extension MoveNodeToWorkspaceCmdArgs {
    public var wrapAround: Bool { _wrapAround ?? false }
    public var useStdin: Bool { explicitStdinFlag ?? false }
}

func implication(ifTrue: Bool, mustHold: @autoclosure () -> Bool) -> Bool { !ifTrue || mustHold() }

public func parseMoveNodeToWorkspaceCmdArgs(_ args: [String]) -> ParsedCmd<MoveNodeToWorkspaceCmdArgs> {
    parseSpecificCmdArgs(MoveNodeToWorkspaceCmdArgs(rawArgs: .init(args)), args)
        .filter("--wrapAround requires using (prev|next) argument") { ($0._wrapAround != nil).implies($0.target.val.isRelatve) }
        .filterNot("--fail-if-noop is incompatible with (next|prev)") { $0.failIfNoop && $0.target.val.isRelatve }
        .filterNot("--window-id is incompatible with (next|prev)") { $0.windowId != nil && $0.target.val.isRelatve }
        .filter("--stdin and --no-stdin require using \(NextPrev.unionLiteral) argument") { ($0.explicitStdinFlag != nil).implies($0.target.val.isRelatve) }
}
