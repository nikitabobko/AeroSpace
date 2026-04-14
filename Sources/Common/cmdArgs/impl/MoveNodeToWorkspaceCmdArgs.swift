public struct MoveNodeToWorkspaceCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public static let parser: CmdParser<Self> = .init(
        kind: .moveNodeToWorkspace,
        allowInConfig: true,
        help: move_node_to_workspace_help_generated,
        flags: [
            "--wrap-around": ArgParser(\._wrapAround, constSubArgParserFun(true)),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
            "--window-id": windowIdSubArgParser(),
            "--focus-follows-window": ArgParser(\.focusFollowsWindow, constSubArgParserFun(true)),

            "--stdin": ArgParser(\.explicitStdinFlag, constSubArgParserFun(true)),
            "--no-stdin": ArgParser(\.explicitStdinFlag, constSubArgParserFun(false)),
        ],
        posArgs: [newMandatoryPosArgParser(\.target, parseWorkspaceTarget, placeholder: workspaceTargetPlaceholder)],
        conflictingOptions: [
            ["--stdin", "--no-stdin"],
        ],
    )

    public var _wrapAround: Bool?
    public var explicitStdinFlag: Bool? = nil
    public var failIfNoop: Bool = false
    public var focusFollowsWindow: Bool = false
    public var target: Lateinit<WorkspaceTarget> = .uninitialized

    public init(rawArgs: StrArrSlice) {
        self.commonState = .init(rawArgs)
    }
}

extension MoveNodeToWorkspaceCmdArgs {
    public var wrapAround: Bool { _wrapAround ?? false }
    public var useStdin: Bool { explicitStdinFlag ?? false }
}

func parseMoveNodeToWorkspaceCmdArgs(_ args: StrArrSlice) -> ParsedCmd<MoveNodeToWorkspaceCmdArgs> {
    parseSpecificCmdArgs(MoveNodeToWorkspaceCmdArgs(rawArgs: args), args)
        .filter("--wrapAround requires using (prev|next) argument") { ($0._wrapAround != nil).implies($0.target.val.isRelatve) }
        .filterNot("--fail-if-noop is incompatible with (next|prev)") { $0.failIfNoop && $0.target.val.isRelatve }
        .filterNot("--window-id is incompatible with (next|prev)") { $0.windowId != nil && $0.target.val.isRelatve }
        .filter("--stdin and --no-stdin require using \(NextPrev.unionLiteral) argument") { ($0.explicitStdinFlag != nil).implies($0.target.val.isRelatve) }
}
