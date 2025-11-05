public struct SummonWorkspaceCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .summonWorkspace,
        allowInConfig: true,
        help: summon_workspace_help_generated,
        flags: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        posArgs: [newArgParser(\.target, parseWorkspaceName, mandatoryArgPlaceholder: "<workspace>")],
    )

    public var target: Lateinit<WorkspaceName> = .uninitialized
    public var failIfNoop: Bool = false
}

private func parseWorkspaceName(i: ArgParserInput) -> ParsedCliArgs<WorkspaceName> {
    .init(WorkspaceName.parse(i.arg), advanceBy: 1)
}
